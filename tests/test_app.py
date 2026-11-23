from app.main import app


def test_health():
    res = app.test_client().get("/health")
    assert res.status_code == 200 and res.get_json()["status"] == "ok"


def test_info_reads_proxy_headers(monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    res = app.test_client().get("/api/info", headers={"X-Real-IP": "203.0.113.7", "X-Forwarded-Proto": "https"})
    body = res.get_json()
    assert body["client_ip"] == "203.0.113.7"
    assert body["forwarded_proto"] == "https"
    assert body["environment"] == "production"
