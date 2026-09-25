"""MG90S feeder gate servo — driven via gpiozero's default pin factory
(RPi.GPIO). This gate only ever holds two fixed positions briefly (open to
dispense, closed the rest of the time), not a continuously-adjusted angle,
so RPi.GPIO's software-PWM jitter isn't a real problem here — a smoother
DMA-based backend like pigpio would be nicer but isn't required. (pigpio's
daemon package has been dropped from current Raspberry Pi OS releases
["Trixie" and later], so this avoids depending on it at all.)

Wiring:
  Signal -> config.SERVO_PIN
  VCC    -> a SEPARATE 5V supply, not the Pi's own 5V rail — a stalling
            servo can pull enough current to brown out the Pi mid-feed
  GND    -> tied to both that supply's GND and the Pi's GND (common
            ground — required for the signal wire to work at all)
"""
from gpiozero import AngularServo


class FeederServo:
    def __init__(self, pin: int, closed_angle: float, open_angle: float):
        # min_angle/max_angle span both calibrated angles regardless of
        # which one ends up numerically larger for your gate mechanism.
        self._servo = AngularServo(
            pin,
            min_angle=0,
            max_angle=180,
            min_pulse_width=0.0005,
            max_pulse_width=0.0025,
        )
        self._closed_angle = closed_angle
        self._open_angle = open_angle
        self.close()

    def open(self):
        self._servo.angle = self._open_angle

    def close(self):
        self._servo.angle = self._closed_angle
