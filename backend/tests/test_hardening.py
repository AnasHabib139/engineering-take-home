import logging

import pytest
from fastapi.testclient import TestClient

from app import api

PATIENT_1 = {"Authorization": "Bearer patient-1"}
CLINICIAN_1 = {"Authorization": "Bearer clinician-1"}


def test_request_logs_contain_no_health_data(
    client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    caplog.set_level(logging.INFO, logger="diary.requests")
    entry = {
        "recorded_at": "2026-10-05T08:30:00+02:00",
        "mood": 4,
        "symptoms": ["migraine"],
        "note": "SECRET-NOTE",
    }
    client.post("/entries", json=entry, headers=PATIENT_1)
    client.get("/clinician/patients/1/entries", headers=CLINICIAN_1)

    assert "POST /entries -> 201" in caplog.text
    assert "GET /clinician/patients/{patient_id}/entries -> 404" in caplog.text
    assert "SECRET-NOTE" not in caplog.text
    assert "migraine" not in caplog.text


def test_unexpected_errors_reveal_nothing_and_are_still_counted(
    client: TestClient, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    def broken(*_: object) -> None:
        raise RuntimeError("SELECT secret FROM patients WHERE email = 'anna.becker@example.com'")

    monkeypatch.setattr(api, "select", broken)

    response = client.get("/clinicians", headers=PATIENT_1)

    assert response.status_code == 500
    assert response.json() == {"detail": "Internal server error"}
    assert 'route="/clinicians",status="500"' in client.get("/metrics").text
    assert "anna.becker" not in caplog.text
