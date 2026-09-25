"""Correctness tests for the closed-loop feeding engine and the HTTP
contract — no real GPIO needed since feeding_engine.py, telemetry.py, and
api/routes.py take hardware as injected objects/callbacks rather than
importing RPi.GPIO directly. Run with:

    cd raspberry_pi && pip install -r requirements-dev.txt && pytest
"""
import time

from fastapi.testclient import TestClient

from api.routes import create_app
from services.feeding_engine import FeedingEngine
from services.telemetry import SharedState


class FakeServo:
    def __init__(self):
        self.is_open = False
        self.close_calls = 0

    def open(self):
        self.is_open = True

    def close(self):
        self.is_open = False
        self.close_calls += 1


def test_feeding_engine_reaches_target():
    servo = FakeServo()
    weight = {"g": 10.0}
    engine = FeedingEngine(servo, lambda: weight["g"], timeout_s=8.0)

    job = engine.start_feed(45)
    assert job is not None
    assert servo.is_open
    assert job.status == "dispensing"

    for delta in (10, 20, 35, 45):
        weight["g"] = 10.0 + delta
        engine.tick()

    assert job.status == "done"
    assert job.dispensed_grams == 45
    assert not servo.is_open
    assert servo.close_calls == 1


def test_feeding_engine_rejects_concurrent_feed():
    servo = FakeServo()
    weight = {"g": 0.0}
    engine = FeedingEngine(servo, lambda: weight["g"], timeout_s=8.0)

    assert engine.start_feed(30) is not None
    assert engine.start_feed(20) is None  # caller maps this to HTTP 409


def test_feeding_engine_timeout_reports_error():
    servo = FakeServo()
    weight = {"g": 0.0}
    engine = FeedingEngine(servo, lambda: weight["g"], timeout_s=0.05)

    job = engine.start_feed(999)
    time.sleep(0.1)
    engine.tick()

    assert job.status == "error"
    assert not servo.is_open


def _client():
    state = SharedState()
    with state.lock:
        state.bowl_weight_grams = 12.5
        state.food_level_pct = 78
        state.last_distance_cm = 8.4
        state.sensor_error = False
    servo = FakeServo()
    weight = {"g": 12.5}
    engine = FeedingEngine(servo, lambda: weight["g"], timeout_s=8.0)
    return TestClient(create_app(state, engine))


def test_health():
    assert _client().get("/health").json() == {"ok": True}


def test_telemetry_shape_matches_api_contract():
    body = _client().get("/api/v1/telemetry").json()
    assert set(body.keys()) == {
        "bowl_weight_grams", "food_level_pct", "bowl_height_cm",
        "next_feed_time", "next_feed_grams", "connectivity",
        "last_updated", "last_refilled",
    }
    assert body["bowl_weight_grams"] == 12.5
    assert body["food_level_pct"] == 78
    assert body["bowl_height_cm"] == 8.4
    assert body["connectivity"] == "online"


def test_manual_feed_lifecycle_and_409():
    client = _client()

    r = client.post("/api/v1/feed/manual", json={"grams": 45})
    assert r.status_code == 200
    job_id = r.json()["job_id"]

    r2 = client.post("/api/v1/feed/manual", json={"grams": 10})
    assert r2.status_code == 409
    assert r2.json() == {"error": "feed already in progress"}

    r3 = client.get(f"/api/v1/feed/manual/{job_id}")
    assert r3.status_code == 200
    assert set(r3.json().keys()) == {"status", "dispensed_grams"}


def test_unknown_job_is_404():
    r = _client().get("/api/v1/feed/manual/does-not-exist")
    assert r.status_code == 404
    assert r.json() == {"error": "unknown job"}


def test_invalid_grams_is_400():
    r = _client().post("/api/v1/feed/manual", json={"grams": 0})
    assert r.status_code == 400
