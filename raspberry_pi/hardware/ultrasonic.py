"""HC-SR04 ultrasonic sensor — hopper food level.

Wiring:
  VCC  -> 5V (needs real 5V, not 3.3V — verify with a multimeter once
          running off a power bank, not just USB during development)
  GND  -> GND
  TRIG -> config.TRIG_PIN (direct — TRIG is a Pi output, no divider needed)
  ECHO -> config.ECHO_PIN, THROUGH A 1k/2k VOLTAGE DIVIDER
          (ECHO outputs 5V; Pi GPIO inputs are 3.3V-only and NOT 5V-
          tolerant — skipping the divider can permanently damage that
          GPIO pin, unlike the ESP32-S3 build this replaces, always use
          the divider here)
"""
import time
from typing import Optional

import RPi.GPIO as GPIO

_TRIGGER_PULSE_S = 0.00001  # 10us
_ECHO_TIMEOUT_S = 0.03  # 30ms ceiling, same as the old firmware's pulseIn()
_SPEED_OF_SOUND_CM_PER_S = 34300


class Ultrasonic:
    def __init__(self, trig_pin: int, echo_pin: int):
        self._trig = trig_pin
        self._echo = echo_pin
        GPIO.setup(self._trig, GPIO.OUT)
        GPIO.setup(self._echo, GPIO.IN)
        GPIO.output(self._trig, False)

    def read_distance_cm(self) -> Optional[float]:
        GPIO.output(self._trig, True)
        time.sleep(_TRIGGER_PULSE_S)
        GPIO.output(self._trig, False)

        deadline = time.monotonic() + _ECHO_TIMEOUT_S

        pulse_start = time.monotonic()
        while GPIO.input(self._echo) == 0:
            pulse_start = time.monotonic()
            if pulse_start > deadline:
                return None  # sensor not responding — reported as sensor_error

        pulse_end = time.monotonic()
        while GPIO.input(self._echo) == 1:
            pulse_end = time.monotonic()
            if pulse_end > deadline:
                return None

        return (pulse_end - pulse_start) * _SPEED_OF_SOUND_CM_PER_S / 2
