"""PetPulse — Raspberry Pi hub. Entry point: wires up the hardware
drivers, starts the background sensor/feed-progress polling loop, and
serves the same REST contract the old ESP32-S3 hub did (see api/routes.py
and docs/API_CONTRACT.md).

Run directly for development:
    sudo python3 main.py
(root is needed for GPIO access under the classic RPi.GPIO backend, and
because HTTP_PORT defaults to 80 — see config.py and README.md's
"Running as a service" section for the no-root alternative.)

For always-on use, install as a systemd service instead — see
raspberry_pi/petpulse.service and the README.
"""
import socket

import RPi.GPIO as GPIO
import uvicorn

import config
from api.routes import create_app
from hardware.button import FeedButton
from hardware.hx711 import HX711
from hardware.oled import OledDisplay
from hardware.servo import FeederServo
from hardware.ultrasonic import Ultrasonic
from services.feeding_engine import FeedingEngine
from services.telemetry import SharedState, TelemetryLoop


def get_local_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))  # no packet actually sent, just picks the outbound interface
        return s.getsockname()[0]
    except OSError:
        return ""
    finally:
        s.close()


def main():
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)

    state = SharedState()

    hx711 = HX711(config.HX711_DOUT_PIN, config.HX711_SCK_PIN)
    hx711.set_scale(config.LOADCELL_CALIBRATION_FACTOR)
    hx711.tare()

    ultrasonic = Ultrasonic(config.TRIG_PIN, config.ECHO_PIN)
    oled = OledDisplay(config.OLED_I2C_PORT, config.OLED_I2C_ADDRESS)
    if not oled.ok:
        print("OLED not found at boot - continuing without it.")

    servo = FeederServo(
        config.SERVO_PIN, config.SERVO_CLOSED_ANGLE, config.SERVO_OPEN_ANGLE
    )

    def get_bowl_weight() -> float:
        with state.lock:
            return state.bowl_weight_grams

    feeding_engine = FeedingEngine(servo, get_bowl_weight, config.FEED_TIMEOUT_S)

    def on_button_press():
        if not feeding_engine.is_dispensing:
            feeding_engine.start_feed(config.BUTTON_FEED_GRAMS)

    FeedButton(config.BUTTON_PIN, on_press=on_button_press)

    ip = get_local_ip()
    oled.show_status(ip or "Wi-Fi FAILED")
    print(f"PetPulse Pi hub starting. IP address: {ip or '(none — check Wi-Fi)'}")

    loop = TelemetryLoop(
        hx711,
        ultrasonic,
        oled,
        feeding_engine,
        state,
        config.HOPPER_EMPTY_CM,
        config.HOPPER_FULL_CM,
        config.SENSOR_POLL_INTERVAL_S,
        config.OLED_UPDATE_INTERVAL_S,
        get_ip=lambda: ip,
    )
    loop.start()

    app = create_app(state, feeding_engine)
    try:
        uvicorn.run(app, host="0.0.0.0", port=config.HTTP_PORT)
    finally:
        loop.stop()
        GPIO.cleanup()


if __name__ == "__main__":
    main()
