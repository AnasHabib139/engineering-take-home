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
