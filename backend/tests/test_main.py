from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "ShopSphere API is live!"}


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert "version" in data
    assert data["version"] == "1.0.0"
    assert "services" in data
    assert data["services"]["database"] == "connected"
    assert data["services"]["redis"] == "connected"


def test_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/plain; charset=utf-8"


def test_cors_headers():
    response = client.options("/health")
    assert response.status_code == 200


def test_openapi_docs():
    response = client.get("/docs")
    assert response.status_code == 200


def test_openapi_json():
    response = client.get("/openapi.json")
    assert response.status_code == 200
    data = response.json()
    assert "components" in data
    assert "securitySchemes" in data["components"]
    assert "BearerAuth" in data["components"]["securitySchemes"]
