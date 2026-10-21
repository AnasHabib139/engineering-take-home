from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, SQLAlchemyError

from app import api
from app.db import SessionLocal
from app.models import DiaryEntry

PATIENT_1 = {"Authorization": "Bearer patient-1"}  # Europe/Berlin
PATIENT_2 = {"Authorization": "Bearer patient-2"}
CLINICIAN_1 = {"Authorization": "Bearer clinician-1"}
CLINICIAN_2 = {"Authorization": "Bearer clinician-2"}
READ = "/clinician/patients/1/entries"


def share(client: TestClient, from_date: str, to_date: str, **extra: object) -> int:
    body = {"clinician_id": 1, "from_date": from_date, "to_date": to_date, **extra}
    return client.post("/shares", json=body, headers=PATIENT_1).json()["id"]


def entry(client: TestClient, recorded_at: str, note: str | None = "private") -> int:
    body = {"recorded_at": recorded_at, "mood": 3, "symptoms": ["headache"], "note": note}
    return client.post("/entries", json=body, headers=PATIENT_1).json()["id"]


def test_doctor_sees_shared_period_inclusive_newest_first_without_notes(
    client: TestClient,
) -> None:
    before = entry(client, "2026-09-30T12:00:00+02:00")
    first = entry(client, "2026-10-01T08:00:00+02:00")
    last = entry(client, "2026-10-07T23:59:00+02:00")
    after = entry(client, "2026-10-08T00:01:00+02:00")
    share(client, "2026-10-01", "2026-10-07")

    response = client.get(READ, headers=CLINICIAN_1)

    assert response.status_code == 200
    assert [e["id"] for e in response.json()] == [last, first]
    assert {before, after}.isdisjoint(e["id"] for e in response.json())
    assert response.json()[0] == {
        "id": last,
        "recorded_at": "2026-10-07T21:59:00Z",
        "mood": 3,
        "symptoms": ["headache"],
        "note": None,
    }


def test_notes_are_shown_only_when_included(client: TestClient) -> None:
    entry(client, "2026-10-02T08:00:00+02:00", note="Slept badly")
    share_id = share(client, "2026-10-02", "2026-10-02", include_notes=True)

    assert client.get(READ, headers=CLINICIAN_1).json()[0]["note"] == "Slept badly"

    client.post(f"/shares/{share_id}/revoke", headers=PATIENT_1)
    share(client, "2026-10-02", "2026-10-02")
    assert client.get(READ, headers=CLINICIAN_1).json()[0]["note"] is None


def test_days_are_the_patients_days_not_utc_days(client: TestClient) -> None:
    # 00:30 in Berlin on 2 October is still 1 October in UTC.
    late = entry(client, "2026-10-02T00:30:00+02:00")
    share(client, "2026-10-01", "2026-10-01")
    assert client.get(READ, headers=CLINICIAN_1).json() == []

    share(client, "2026-10-02", "2026-10-02")
    assert [e["id"] for e in client.get(READ, headers=CLINICIAN_1).json()] == [late]


def test_app_v1_entries_are_read_as_local_time(client: TestClient) -> None:
    # Written at 23:50 Berlin time on 14 March, stored as 23:50 UTC.
    with SessionLocal() as db:
        v1 = DiaryEntry(
            patient_id=1,
            recorded_at=datetime(2026, 3, 14, 23, 50, tzinfo=UTC),
            mood=2,
            symptoms=[],
            source="app-v1",
        )
        db.add(v1)
        db.commit()
    share(client, "2026-03-15", "2026-03-15")
    assert client.get(READ, headers=CLINICIAN_1).json() == []

    share(client, "2026-03-14", "2026-03-14")
    entries = client.get(READ, headers=CLINICIAN_1).json()
    assert [e["id"] for e in entries] == [v1.id]
    assert entries[0]["recorded_at"] == "2026-03-14T22:50:00Z"


def test_no_share_and_unknown_patient_look_the_same(client: TestClient) -> None:
    entry(client, "2026-10-02T08:00:00+02:00")
    known = client.get(READ, headers=CLINICIAN_1)
    unknown = client.get("/clinician/patients/999/entries", headers=CLINICIAN_1)

    assert (known.status_code, known.json()) == (unknown.status_code, unknown.json())
    assert known.status_code == 404


def test_other_doctors_and_revoked_shares_get_nothing(client: TestClient) -> None:
    entry(client, "2026-10-02T08:00:00+02:00")
    share_id = share(client, "2026-10-02", "2026-10-02")

    assert client.get(READ, headers=CLINICIAN_2).status_code == 404
    assert client.get(READ, headers=CLINICIAN_1).status_code == 200

    client.post(f"/shares/{share_id}/revoke", headers=PATIENT_1)
    assert client.get(READ, headers=CLINICIAN_1).status_code == 404


def test_only_clinicians_may_read(client: TestClient) -> None:
    assert client.get(READ, headers=PATIENT_1).status_code == 403
    assert client.get(READ).status_code == 401


def test_reads_are_recorded_and_shown_to_the_patient(client: TestClient) -> None:
    first = entry(client, "2026-10-02T08:00:00+02:00")
    second = entry(client, "2026-10-03T08:00:00+02:00")
    share(client, "2026-10-02", "2026-10-02")
    client.get(READ, headers=CLINICIAN_1)
    share(client, "2026-10-03", "2026-10-03")
    client.get(READ, headers=CLINICIAN_1)
    client.get(READ, headers=CLINICIAN_2)  # denied reads are not accesses

    log = client.get("/access-log", headers=PATIENT_1).json()

    assert [row["entry_ids"] for row in log] == [[second, first], [first]]
    assert log[0]["clinician_id"] == 1
    assert log[0]["clinician_name"] == "Dr. Lena Hofmann"
    assert log[0]["accessed_at"].endswith("Z")
    assert client.get("/access-log", headers=PATIENT_2).json() == []
    assert client.get("/access-log", headers=CLINICIAN_1).status_code == 403


def test_a_read_with_no_entries_is_still_recorded(client: TestClient) -> None:
    share(client, "2026-10-02", "2026-10-02")
    client.get(READ, headers=CLINICIAN_1)

    assert [r["entry_ids"] for r in client.get("/access-log", headers=PATIENT_1).json()] == [[]]


def test_access_log_cannot_be_changed(client: TestClient) -> None:
    share(client, "2026-10-02", "2026-10-02")
    client.get(READ, headers=CLINICIAN_1)

    for statement in ("UPDATE access_log SET entry_ids = '{}'", "DELETE FROM access_log"):
        with SessionLocal() as db, pytest.raises(DBAPIError):
            db.execute(text(statement))
    assert len(client.get("/access-log", headers=PATIENT_1).json()) == 1


def test_no_data_is_returned_when_the_access_cannot_be_recorded(
    client: TestClient, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    def broken(**_: object) -> None:
        raise SQLAlchemyError("boom")

    entry(client, "2026-10-02T08:00:00+02:00")
    share(client, "2026-10-02", "2026-10-02")
    monkeypatch.setattr(api, "AccessLog", broken)

    response = client.get(READ, headers=CLINICIAN_1)

    assert response.status_code == 500
    assert response.json() == {"detail": "Could not record access"}
    assert "access_log_write_failures_total 1.0" in client.get("/metrics").text
    assert "Access log write failed: SQLAlchemyError" in caplog.text
    assert "boom" not in caplog.text
