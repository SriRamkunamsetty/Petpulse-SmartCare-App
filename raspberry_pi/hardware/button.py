"""Physical manual-feed button — internal pull-up, other leg to GND
(same wiring as the old ESP32-S3 build's INPUT_PULLUP button)."""
from gpiozero import Button


class FeedButton:
    def __init__(self, pin: int, on_press):
        self._button = Button(pin, pull_up=True, bounce_time=0.05)
        self._button.when_pressed = on_press
