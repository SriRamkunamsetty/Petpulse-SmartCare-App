"""MG90S feeder gate servo — driven via gpiozero + the pigpio pin factory
for jitter-free PWM. RPi.GPIO's software PWM isn't precise enough to hold
a servo at a stable angle without visible twitch; pigpio uses DMA-based
timing instead. Start the daemon before running this:

    sudo apt install pigpio python3-pigpio
    sudo systemctl enable --now pigpiod

Wiring:
  Signal -> config.SERVO_PIN
  VCC    -> a SEPARATE 5V supply, not the Pi's own 5V rail — a stalling
            servo can pull enough current to brown out the Pi mid-feed
  GND    -> tied to both that supply's GND and the Pi's GND (common
            ground — required for the signal wire to work at all)
"""
from gpiozero import AngularServo
from gpiozero.pins.pigpio import PiGPIOFactory


class FeederServo:
    def __init__(self, pin: int, closed_angle: float, open_angle: float):
        factory = PiGPIOFactory()
        # min_angle/max_angle span both calibrated angles regardless of
        # which one ends up numerically larger for your gate mechanism.
        self._servo = AngularServo(
            pin,
            min_angle=0,
            max_angle=180,
            min_pulse_width=0.0005,
            max_pulse_width=0.0025,
            pin_factory=factory,
        )
        self._closed_angle = closed_angle
        self._open_angle = open_angle
        self.close()

    def open(self):
        self._servo.angle = self._open_angle

    def close(self):
        self._servo.angle = self._closed_angle
