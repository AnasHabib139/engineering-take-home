from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api import CONSENT_VERSION
from app.db import SessionLocal
from app.models import Share

PATIENT_1 = {"Authorization": "Bearer patient-1"}
PATIENT_2 = {"Authorization": "Bearer patient-2"}
CLINICIAN_1 = {"Authorization": "Bearer clinician-1"}
SHARE = {"clinician_id": 1, "from_date": "2026-10-01", "to_date": "2026-10-07"}


def test_patient_creates_share_without_notes_by_default(client: TestClient) -> None:
    response = client.post("/shares", json=SHARE, headers=PATIENT_1)

    assert response.status_code == 201
    share = response.json()
    assert share | {"id": 1, "created_at": None} == {
        **SHARE,
        "id": 1,
        "include_notes": False,
        "created_at": None,
        "revoked_at": None,
    }
    assert share["created_at"].endswith("Z")


def test_share_stores_the_version_of_the_consent_text(client: TestClient) -> None:
    client.post("/shares", json=SHARE, headers=PATIENT_1)

    with SessionLocal() as db:
        assert db.scalar(select(Share.consent_version)) == CONSENT_VERSION


def test_patient_can_include_notes(client: TestClient) -> None:
    share = client.post("/shares", json={**SHARE, "include_notes": True}, headers=PATIENT_1)

    assert share.json()["include_notes"] is True


def test_shares_are_listed_newest_first_and_only_own(client: TestClient) -> None:
    first = client.post("/shares", json=SHARE, headers=PATIENT_1).json()
    second = client.post("/shares", json={**SHARE, "clinician_id": 2}, headers=PATIENT_1).json()
    client.post("/shares", json=SHARE, headers=PATIENT_2)

    ids = [s["id"] for s in client.get("/shares", headers=PATIENT_1).json()]
    assert ids == [second["id"], first["id"]]


def test_revoke_sets_revoked_at_and_is_idempotent(client: TestClient) -> None:
    share_id = client.post("/shares", json=SHARE, headers=PATIENT_1).json()["id"]

    revoked = client.post(f"/shares/{share_id}/revoke", headers=PATIENT_1)
    again = client.post(f"/shares/{share_id}/revoke", headers=PATIENT_1)

    assert revoked.status_code == 200
    assert revoked.json()["revoked_at"] is not None
    assert again.json()["revoked_at"] == revoked.json()["revoked_at"]


def test_patient_cannot_revoke_someone_elses_share(client: TestClient) -> None:
    share_id = client.post("/shares", json=SHARE, headers=PATIENT_1).json()["id"]

    assert client.post(f"/shares/{share_id}/revoke", headers=PATIENT_2).status_code == 404
    assert client.get("/shares", headers=PATIENT_1).json()[0]["revoked_at"] is None
    assert client.post("/shares/999/revoke", headers=PATIENT_1).status_code == 404


def test_rejects_invalid_shares(client: TestClient) -> None:
    invalid_shares = (
        {**SHARE, "from_date": "2026-10-08"},  # period ends before it starts
        {**SHARE, "to_date": "not-a-date"},
        {**SHARE, "clinician_id": 99},
        {**SHARE, "include_notes": "maybe"},
        {"clinician_id": 1},
    )
    for invalid in invalid_shares:
        assert client.post("/shares", json=invalid, headers=PATIENT_1).status_code == 422


def test_single_day_share_is_valid(client: TestClient) -> None:
    single_day = {**SHARE, "to_date": SHARE["from_date"]}

    assert client.post("/shares", json=single_day, headers=PATIENT_1).status_code == 201


def test_sharing_is_for_patients_only(client: TestClient) -> None:
    assert client.post("/shares", json=SHARE, headers=CLINICIAN_1).status_code == 403
    assert client.get("/shares", headers=CLINICIAN_1).status_code == 403
    assert client.post("/shares/1/revoke", headers=CLINICIAN_1).status_code == 403
    assert client.get("/shares").status_code == 401


def metric(client: TestClient, name: str) -> float:
    lines = client.get("/metrics").text.splitlines()
    return next(float(line.split()[1]) for line in lines if line.startswith(f"{name} "))


def test_metrics_count_shares_without_patient_data(client: TestClient) -> None:
    created, revoked = (metric(client, n) for n in ("shares_created_total", "shares_revoked_total"))

    share_id = client.post("/shares", json=SHARE, headers=PATIENT_1).json()["id"]
    client.post(f"/shares/{share_id}/revoke", headers=PATIENT_1)

    assert metric(client, "shares_created_total") == created + 1
    assert metric(client, "shares_revoked_total") == revoked + 1
