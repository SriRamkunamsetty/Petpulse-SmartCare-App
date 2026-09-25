"""PetPulse — Raspberry Pi hub configuration.

BCM GPIO numbering throughout (what RPi.GPIO/gpiozero expect by default,
NOT the physical header pin numbers) — run `pinout` on the Pi to cross-
reference BCM numbers against physical pin positions.

This is a STARTING pin map, not gospel — cross-check against anything else
wired to the Pi's 40-pin header before committing to a breadboard, same
discipline the old ESP32-S3 build's pin map asked for.
"""

# ── Pins ─────────────────────────────────────────────────────────────────
HX711_DOUT_PIN = 5
HX711_SCK_PIN = 6

TRIG_PIN = 23
ECHO_PIN = 24  # through a 1k/2k divider — Pi GPIO is 3.3V-only, ECHO is 5V

BUTTON_PIN = 16  # internal pull-up; other leg to GND

SERVO_PIN = 18  # hardware-PWM-capable pin; use with the pigpio factory (see
                 # hardware/servo.py) for jitter-free control

# OLED (SSD1306) is I2C — uses the Pi's dedicated I2C pins (GPIO2 SDA /
# GPIO3 SCL, physical pins 3/5), not GPIO numbers you choose. Enable I2C
# first: `sudo raspi-config` -> Interface Options -> I2C -> enable, reboot.
OLED_I2C_PORT = 1
OLED_I2C_ADDRESS = 0x3C

# ── Calibration — measure these for YOUR hardware, same as the old build ──
# From load_cell_test.ino (or an equivalent bench test):
# raw_reading_with_known_weight / known_weight_grams.
LOADCELL_CALIBRATION_FACTOR = 420.0
# Distance (cm) from the ultrasonic sensor to the hopper floor when EMPTY,
# and to the food surface when FULL.
HOPPER_EMPTY_CM = 20.0
HOPPER_FULL_CM = 3.0
# Physical override portion size when the button is pressed.
BUTTON_FEED_GRAMS = 45

# MG90S angles for your gate mechanism — calibrate on the bench, same
# caveat as before: confirm nothing binds before relying on it unattended.
SERVO_CLOSED_ANGLE = 0
SERVO_OPEN_ANGLE = 90
# Safety backstop: if the load cell never sees the target weight land
# within this long (empty hopper, jam, gate stuck), stop and report an
# error rather than holding the gate open indefinitely.
FEED_TIMEOUT_S = 8.0

# ── Server ───────────────────────────────────────────────────────────────
# Port 80 matches the app's Settings -> Feeder Hub field expecting just an
# IP with no port (same UX as the ESP32-S3 build). Binding port 80 needs
# root — see raspberry_pi/README.md "Running as a service" for the
# no-root alternative (port 8080 + typing "<ip>:8080" into that field).
HTTP_PORT = 80

SENSOR_POLL_INTERVAL_S = 1.0
OLED_UPDATE_INTERVAL_S = 1.0
