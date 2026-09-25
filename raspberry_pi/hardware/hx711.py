"""HX711 load cell amplifier — bit-banged over plain GPIO, no external
HX711 Python package needed beyond RPi.GPIO. Mirrors the API shape of the
bogde/HX711 Arduino library (is_ready/set_scale/tare/get_units) so the
feeding engine reads it the same way the old ESP32-S3 firmware did.

Wiring:
  HX711 VCC -> Pi 3.3V
  HX711 GND -> Pi GND
  HX711 DT  -> config.HX711_DOUT_PIN
  HX711 SCK -> config.HX711_SCK_PIN
  Load cell E+/E-/A+/A- -> HX711 E+/E-/A+/A- (match your load cell's own
  labels/datasheet, not wire color — colors aren't standardized)
"""
import statistics
import time

import RPi.GPIO as GPIO

# Extra clock pulses after the 24 data bits select the gain/channel used
# for the *next* conversion — 1/2/3 pulses for channel A gain 128, channel
# B gain 32, and channel A gain 64 respectively (per the HX711 datasheet).
_GAIN_PULSES = {128: 1, 32: 2, 64: 3}


class HX711:
    def __init__(self, dout_pin: int, sck_pin: int, gain: int = 128):
        self._dout = dout_pin
        self._sck = sck_pin
        GPIO.setup(self._dout, GPIO.IN)
        GPIO.setup(self._sck, GPIO.OUT)
        GPIO.output(self._sck, False)
        self._gain_pulses = _GAIN_PULSES[gain]
        self._offset = 0.0
        self._scale = 1.0

    def is_ready(self) -> bool:
        return GPIO.input(self._dout) == 0

    def _read_raw(self) -> int:
        # Wait for a conversion to be ready (DOUT goes low) — same blocking
        # wait as the Arduino library, capped so a disconnected sensor
        # can't hang the polling thread forever.
        start = time.monotonic()
        while GPIO.input(self._dout) == 1:
            if time.monotonic() - start > 1.0:
                raise TimeoutError("HX711 not ready (check wiring/power)")
            time.sleep(0.001)

        value = 0
        for _ in range(24):
            GPIO.output(self._sck, True)
            value = (value << 1) | GPIO.input(self._dout)
            GPIO.output(self._sck, False)

        for _ in range(self._gain_pulses):
            GPIO.output(self._sck, True)
            GPIO.output(self._sck, False)

        if value & 0x800000:  # sign bit of a 24-bit two's-complement value
            value -= 1 << 24
        return value

    def read_average(self, times: int = 3) -> float:
        return statistics.mean(self._read_raw() for _ in range(times))

    def set_scale(self, scale: float):
        self._scale = scale

    def tare(self, times: int = 15):
        self._offset = self.read_average(times)

    def get_units(self, times: int = 3) -> float:
        return (self.read_average(times) - self._offset) / self._scale
