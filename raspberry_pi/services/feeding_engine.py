"""Closed-loop feed dispensing — ports the *behavior* of the old ESP32-S3
firmware (see firmware/esp32s3_hub/esp32s3_hub.ino, "Feed dispensing")
unchanged: open the gate, watch the load cell's live weight climb, close
the instant the target lands, with a timeout backstop for a jam or empty
hopper. The MG90S has no position feedback of its own, same as the SG90
did — the load cell is still what actually confirms delivery, not a timer.
"""
import threading
import time
import uuid
from typing import Callable, Optional


class FeedJob:
    def __init__(self, job_id: str, target_grams: int, start_weight_g: float):
        self.id = job_id
        self.target_grams = target_grams
        self.dispensed_grams = 0
        self.status = "dispensing"  # "dispensing" | "done" | "error"
        self.start_weight_g = start_weight_g
        self.started_at = time.monotonic()


class FeedingEngine:
    def __init__(
        self,
        servo,
        get_bowl_weight: Callable[[], float],
        timeout_s: float,
    ):
        self._servo = servo
        self._get_bowl_weight = get_bowl_weight
        self._timeout_s = timeout_s
        self._lock = threading.Lock()
        self._active_job: Optional[FeedJob] = None

    def start_feed(self, grams: int) -> Optional[FeedJob]:
        """Returns None if a feed is already in progress — caller should
        turn that into an HTTP 409, matching the old firmware's
        handleFeedManual()."""
        with self._lock:
            if self._active_job is not None and self._active_job.status == "dispensing":
                return None
            job = FeedJob(str(uuid.uuid4()), grams, self._get_bowl_weight())
            self._active_job = job
            self._servo.open()
            return job

    def tick(self):
        """Call once per polling-loop iteration — advances the active
        job's progress and closes the gate on completion/timeout. Mirrors
        updateFeedProgress() being called from the old firmware's loop()."""
        with self._lock:
            job = self._active_job
            if job is None or job.status != "dispensing":
                return

            dispensed = max(0.0, self._get_bowl_weight() - job.start_weight_g)
            job.dispensed_grams = int(dispensed)

            reached_target = dispensed >= job.target_grams
            timed_out = (time.monotonic() - job.started_at) > self._timeout_s
            if not reached_target and not timed_out:
                return

            self._servo.close()
            if reached_target:
                job.dispensed_grams = job.target_grams
                job.status = "done"
            else:
                # Timed out short of the target — hopper empty, jam, or
                # gate stuck.
                job.status = "error"

    def get_job(self, job_id: str) -> Optional[FeedJob]:
        with self._lock:
            job = self._active_job
            return job if job is not None and job.id == job_id else None

    @property
    def is_dispensing(self) -> bool:
        with self._lock:
            return self._active_job is not None and self._active_job.status == "dispensing"
