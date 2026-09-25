# PetPulse — Raspberry Pi hub

An alternative to `firmware/esp32s3_hub/esp32s3_hub.ino`: the Raspberry Pi
takes over as the **main controller** — load cell, ultrasonic sensor,
feeder servo, OLED, physical button, and the same REST API the app already
speaks. The **ESP32-CAM stays exactly as it was** (`firmware/esp32_cam/`)
— it's already a fully independent board with its own IP, and nothing here
changes that.

```
                     📱 Flutter app
                         │
                    same REST contract
                         │
                         ▼
               ┌───────────────────┐
               │   RASPBERRY PI    │
               │                   │
               │  FastAPI + Python │
               └─────────┬─────────┘
                         │
          ┌───────────────────┼──────────────────┐
          │                   │                  │
          ▼                   ▼                  ▼
       HX711               MG90S               OLED
      (load cell)        (feeder gate)      (status display)
          │
          ▼
     HC-SR04 (food level)


                    ESP32-CAM (unchanged, separate board/IP)
```

**Why the app doesn't need to change:** the Pi implements the exact same
four endpoints the ESP32-S3 build served —
`GET /health`, `GET /api/v1/telemetry`, `POST /api/v1/feed/manual`,
`GET /api/v1/feed/manual/{job_id}` — with the same JSON shape (see
`docs/API_CONTRACT.md` and `api/routes.py`). You still just type an IP
into **Settings → Feeder Hub**; it's the Pi's IP now instead of the
ESP32-S3's, nothing else in the app changes.

## 1. Wiring

Same sensors, same electrical rules as the ESP32-S3 build — only the pin
*numbers* change (Pi BCM numbering, see `config.py`).

| Component | Pin on component | Connects to Pi |
|---|---|---|
| **HX711** | VCC | 3.3V |
| | GND | GND |
| | DT | GPIO5 |
| | SCK | GPIO6 |
| **Load cell** | E+/E-/A+/A- | HX711's E+/E-/A+/A- |
| **HC-SR04** | VCC | 5V (real 5V, not 3.3V) |
| | GND | GND |
| | TRIG | GPIO23 (direct, no divider needed) |
| | ECHO | GPIO24 — **through a 1k/2k voltage divider** (ECHO is 5V; Pi GPIO is 3.3V-only and NOT 5V-tolerant — skipping this can permanently damage the pin) |
| **Push button** | Leg 1 | GPIO16 |
| | Leg 2 | GND |
| **OLED (SSD1306, I2C)** | VCC | 3.3V |
| | GND | GND |
| | SDA | GPIO2 (physical pin 3 — fixed I2C pin, not a free GPIO choice) |
| | SCL | GPIO3 (physical pin 5) |
| **MG90S servo** | Signal | GPIO18 |
| | VCC | **Separate 5V supply**, not the Pi's own 5V rail — a stalling servo can pull enough current to brown out the Pi mid-feed |
| | GND | Tied to *both* the servo's own supply GND and the Pi's GND |

**Common ground rule still applies**: Pi GND, the servo's supply GND, and
any shared power bank's grounds all need to be tied together, same as
before.

## 2. One-time OS setup

```bash
# Enable I2C for the OLED
sudo raspi-config   # Interface Options -> I2C -> enable, then reboot
```

(No `pigpio` daemon needed — the servo driver uses gpiozero's default
`RPi.GPIO` backend, since `pigpio`'s daemon package was dropped from
current Raspberry Pi OS releases anyway.)

## 3. Install and calibrate

```bash
cd raspberry_pi
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Before trusting this unattended, calibrate the same two things the old
build needed:

- **Load cell**: put a known weight on it, note the raw reading, compute
  `raw_reading / known_weight_grams`, set `LOADCELL_CALIBRATION_FACTOR` in
  `config.py`.
- **Hopper distances**: measure the ultrasonic sensor's distance to the
  hopper floor when EMPTY and to the food surface when FULL, set
  `HOPPER_EMPTY_CM`/`HOPPER_FULL_CM`.
- **Servo angles**: bench-test `SERVO_CLOSED_ANGLE`/`SERVO_OPEN_ANGLE` for
  your actual gate mechanism — the MG90S is a different physical unit from
  whatever the angles were tuned for before, don't assume 0°/90° is right
  without checking nothing binds.

## 4. Run it

```bash
sudo python3 main.py
```

Watch the console for `PetPulse Pi hub starting. IP address: ...` — that's
what goes into the app's **Settings → Feeder Hub** field. The OLED shows
the same IP once it's up, exactly like the ESP32-S3 build did.

Press the physical button, or tap Feed Now in the app — either path opens
the MG90S and watches the load cell's live weight climb to the target,
same closed-loop behavior as before (see `services/feeding_engine.py`).

## 5. Running as a service (24/7, survives reboots)

```bash
sudo cp petpulse.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now petpulse
sudo journalctl -u petpulse -f   # watch logs
```

**Root vs. no-root:** the provided unit runs as `root`, which is the
simplest path — it's needed both for binding port 80 (so the app's Hub
field just takes a bare IP, no port) and for GPIO access under the classic
`RPi.GPIO` backend. If you'd rather not run a network-facing process as
root:

1. Add your user to the `gpio`, `i2c`, and `spi` groups:
   `sudo usermod -aG gpio,i2c,spi $USER` (log out/in after).
2. Set `HTTP_PORT = 8080` in `config.py` (ports below 1024 need root
   regardless of GPIO permissions).
3. Remove `User=root` from `petpulse.service`.
4. In the app's Settings → Feeder Hub field, type `<pi-ip>:8080` instead
   of just the IP — the field accepts that as-is.

## 6. What's intentionally NOT here yet

Matches the old ESP32-S3 build's own scope boundary — auth, device
pairing, schedule storage, history, and alerts all still live on the
cloud/mock server (`app/mock_server`, or your Render deployment), not
here. The Pi only owns what real hardware it's attached to: telemetry and
manual feed. See `docs/API_CONTRACT.md`'s architecture section for why
that split exists, and `app/mock_server/DEPLOY.md` for the cloud side.

If you later want schedule/history/alerts to live on the Pi too instead
of a separate cloud service, that's a real option — SQLite is a natural
fit on a Pi that's already running 24/7 on your LAN — but it's a bigger
step (new database layer, new endpoints, and Flutter would need to stop
treating "hub" and "cloud" as separate base URLs for those calls). Worth
doing once the hardware side above is solid and calibrated, not before.
