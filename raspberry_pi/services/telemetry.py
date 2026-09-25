"""Background sensor-polling loop — mirrors the old ESP32-S3 firmware's
loop(): reads sensors every ~1s, updates the OLED every ~1s, and ticks the
feeding engine on every iteration so a dispense-in-progress advances even
while the HTTP server is otherwise idle. Runs in its own thread since the
GPIO/I2C calls here are blocking and would stall FastAPI's async event
loop if called from a request handler.
"""
import threading
import time
from typing import Callable


class SharedState:
    """Read/written from two threads (this loop, and FastAPI's request
    handlers) — always take `lock` around access."""

    def __init__(self):
        self.lock = threading.Lock()
        self.bowl_weight_grams = 0.0
        self.food_level_pct = 0
        self.last_distance_cm = 0.0
        self.sensor_error = False


class TelemetryLoop(threading.Thread):
    def __init__(
        self,
        hx711,
        ultrasonic,
        oled,
        feeding_engine,
        state: SharedState,
        hopper_empty_cm: float,
        hopper_full_cm: float,
        sensor_interval_s: float,
        oled_interval_s: float,
        get_ip: Callable[[], str],
    ):
        super().__init__(daemon=True)
        self._hx711 = hx711
        self._ultrasonic = ultrasonic
        self._oled = oled
        self._feeding_engine = feeding_engine
        self._state = state
        self._hopper_empty_cm = hopper_empty_cm
        self._hopper_full_cm = hopper_full_cm
        self._sensor_interval_s = sensor_interval_s
        self._oled_interval_s = oled_interval_s
        self._get_ip = get_ip
        self._stop_event = threading.Event()

    def stop(self):
        self._stop_event.set()

    def run(self):
        last_sensor_read = 0.0
        last_oled_update = 0.0
        while not self._stop_event.is_set():
            now = time.monotonic()
            self._feeding_engine.tick()

            if now - last_sensor_read > self._sensor_interval_s:
                last_sensor_read = now
                self._read_sensors()

            if now - last_oled_update > self._oled_interval_s:
                last_oled_update = now
                self._update_oled()

            time.sleep(0.02)

    def _read_sensors(self):
        ok = True

        try:
            weight = max(0.0, self._hx711.get_units(3))
        except TimeoutError:
            with self._state.lock:
                weight = self._state.bowl_weight_grams
            ok = False

        distance = self._ultrasonic.read_distance_cm()
        if distance is None:
            with self._state.lock:
                pct = self._state.food_level_pct
                distance = self._state.last_distance_cm
            ok = False
        else:
            span = self._hopper_empty_cm - self._hopper_full_cm
            pct = (self._hopper_empty_cm - distance) / span * 100.0
            pct = max(0, min(100, int(pct)))

        with self._state.lock:
            self._state.bowl_weight_grams = weight
            self._state.food_level_pct = pct
            self._state.last_distance_cm = distance
            self._state.sensor_error = not ok

    def _update_oled(self):
        with self._state.lock:
            weight = self._state.bowl_weight_grams
            pct = self._state.food_level_pct
            sensor_error = self._state.sensor_error
        self._oled.show_summary(weight, pct, self._get_ip(), sensor_error)
