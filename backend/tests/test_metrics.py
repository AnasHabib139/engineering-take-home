from datetime import UTC, datetime

from fastapi.testclient import TestClient


def test_metrics_count_requests_by_route_template(client: TestClient) -> None:
    client.get("/entries", headers={"Authorization": "Bearer patient-1"})

    metrics = client.get("/metrics").text
    assert 'http_requests_total{method="GET",route="/entries",status="200"}' in metrics


def test_telemetry_counts_app_events(client: TestClient) -> None:
    headers = {"Authorization": "Bearer patient-1"}
    assert (
        client.post("/telemetry", json={"event": "diary_opened"}, headers=headers).status_code
        == 204
    )

    assert 'app_events_total{event="diary_opened"}' in client.get("/metrics").text


def test_telemetry_rejects_free_text(client: TestClient) -> None:
    headers = {"Authorization": "Bearer patient-1"}
    for event in ("Anna Becker", "x" * 65, ""):
        assert client.post("/telemetry", json={"event": event}, headers=headers).status_code == 422


def test_metrics_split_patients_by_sharing_cohort_without_identifying_anyone(
    client: TestClient,
) -> None:
    patient_1 = {"Authorization": "Bearer patient-1"}
    now = datetime.now(UTC).isoformat()
    client.post("/entries", json={"recorded_at": now, "mood": 3}, headers=patient_1)
    client.post(
        "/shares",
        json={"clinician_id": 1, "from_date": "2026-10-01", "to_date": "2026-10-07"},
        headers=patient_1,
    )

    metrics = client.get("/metrics").text

    assert 'diary_patients{cohort="sharers"} 1.0' in metrics
    assert 'diary_patients{cohort="others"} 1.0' in metrics
    assert 'diary_patients_logging_7d{cohort="sharers"} 1.0' in metrics
    assert 'diary_patients_logging_7d{cohort="others"} 0.0' in metrics
    assert "Anna" not in metrics
