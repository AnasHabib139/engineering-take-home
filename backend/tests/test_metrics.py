from fastapi.testclient import TestClient


def test_metrics_count_requests_by_route_template(client: TestClient) -> None:
    client.get("/entries", headers={"Authorization": "Bearer patient-1"})

    metrics = client.get("/metrics").text
    assert 'http_requests_total{method="GET",route="/entries",status="200"}' in metrics
