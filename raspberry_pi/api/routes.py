"""FastAPI routes implementing the subset of docs/API_CONTRACT.md this hub
is responsible for — the same four endpoints the ESP32-S3 build served
(GET /health, GET /api/v1/telemetry, POST /api/v1/feed/manual,
GET /api/v1/feed/manual/{job_id}), same JSON shape, so the Flutter app
needs zero changes beyond pointing Settings -> Feeder Hub at this Pi's IP.

No auth here either, for the same reason the old firmware had none: this
is meant to be reached only on your trusted home LAN once the app already
has the hub's IP (see docs/API_CONTRACT.md and firmware/README.md for why
that's the deliberate design, not an oversight).
"""
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from services.feeding_engine import FeedingEngine
from services.telemetry import SharedState


def create_app(state: SharedState, feeding_engine: FeedingEngine) -> FastAPI:
    app = FastAPI()

    @app.exception_handler(StarletteHTTPException)
    async def _error_shape(_request, exc: StarletteHTTPException):
        # {"error": "..."} matches mock_server and the old firmware's error
        # body shape (FastAPI's own default is {"detail": "..."}).
        return JSONResponse(status_code=exc.status_code, content={"error": exc.detail})

    @app.get("/health")
    def health():
        return {"ok": True}

    @app.get("/api/v1/telemetry")
    def telemetry():
        with state.lock:
            connectivity = "sensor_error" if state.sensor_error else "online"
            return {
                "bowl_weight_grams": round(state.bowl_weight_grams, 1),
                "food_level_pct": state.food_level_pct,
                "bowl_height_cm": round(state.last_distance_cm, 1),
                # Schedule lives in the app/relay, not the hub — same as
                # the old firmware.
                "next_feed_time": "--:--",
                "next_feed_grams": 0,
                "connectivity": connectivity,
                "last_updated": datetime.now(timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                "last_refilled": "",
            }

    @app.post("/api/v1/feed/manual")
    async def feed_manual(request: Request):
        payload = await request.json()
        grams = int(payload.get("grams") or 0)
        if grams <= 0:
            raise HTTPException(
                status_code=400, detail="grams must be a positive integer"
            )
        job = feeding_engine.start_feed(grams)
        if job is None:
            raise HTTPException(status_code=409, detail="feed already in progress")
        return {"job_id": job.id}

    @app.get("/api/v1/feed/manual/{job_id}")
    def feed_status(job_id: str):
        job = feeding_engine.get_job(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="unknown job")
        return {"status": job.status, "dispensed_grams": job.dispensed_grams}

    return app
