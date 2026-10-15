from fastapi.testclient import TestClient

PATIENT_1 = {"Authorization": "Bearer patient-1"}
PATIENT_2 = {"Authorization": "Bearer patient-2"}
CLINICIAN_1 = {"Authorization": "Bearer clinician-1"}
ENTRY = {
    "recorded_at": "2026-10-05T08:30:00+02:00",
    "mood": 4,
    "symptoms": ["headache"],
    "note": "Slept badly",
}


def test_patient_creates_and_lists_own_entries(client: TestClient) -> None:
    created = client.post("/entries", json=ENTRY, headers=PATIENT_1)
    assert created.status_code == 201

    entries = client.get("/entries", headers=PATIENT_1).json()
    assert [e["id"] for e in entries] == [created.json()["id"]]
    assert entries[0]["recorded_at"] == "2026-10-05T06:30:00Z"


def test_patient_does_not_see_other_patients_entries(client: TestClient) -> None:
    client.post("/entries", json=ENTRY, headers=PATIENT_1)

    assert client.get("/entries", headers=PATIENT_2).json() == []


def test_entries_are_newest_first(client: TestClient) -> None:
    for day in ("03", "05", "04"):
        client.post(
            "/entries", json={**ENTRY, "recorded_at": f"2026-10-{day}T08:00:00Z"}, headers=PATIENT_1
        )

    days = [e["recorded_at"][8:10] for e in client.get("/entries", headers=PATIENT_1).json()]
    assert days == ["05", "04", "03"]


def test_rejects_invalid_entries(client: TestClient) -> None:
    for invalid in ({**ENTRY, "mood": 6}, {**ENTRY, "recorded_at": "2026-10-05T08:30:00"}):
        assert client.post("/entries", json=invalid, headers=PATIENT_1).status_code == 422


def test_entries_are_for_patients_only(client: TestClient) -> None:
    assert client.get("/entries", headers=CLINICIAN_1).status_code == 403


def test_unknown_or_missing_token_is_rejected(client: TestClient) -> None:
    assert client.get("/entries", headers={"Authorization": "Bearer patient-99"}).status_code == 401
    assert client.get("/entries").status_code == 401


def test_clinicians_are_listed_by_name(client: TestClient) -> None:
    names = [c["name"] for c in client.get("/clinicians", headers=PATIENT_1).json()]
    assert names == ["Dr. Felix Braun", "Dr. Lena Hofmann"]
