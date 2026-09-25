# PetPulse firmware

This is the hardware side of PetPulse: the ESP32-S3 hub (which now also
drives the SG90 feeder servo directly) and the ESP32-CAM, plus standalone
diagnostics for every sensor. There is no separate feeder microcontroller
in this build — earlier revisions used an Arduino UNO relayed over UART;
that board and `arduino_uno_feeder.ino` have been retired. Just **two**
boards total now: ESP32-S3 and ESP32-CAM.

> **Using a Raspberry Pi as the main controller instead?** See
> `../raspberry_pi/` — it replaces everything in this document *except*
> the ESP32-CAM section right below, which stays exactly as-is either way
> (the camera is always a separate, independent board). The Raspberry Pi
> build implements the same REST contract as `esp32s3_hub.ino`, so the app
> doesn't need any changes either way.

**Test order — don't skip this.** Flash and verify each sensor on its own
*before* touching the combined hub firmware. A wiring mistake is much
easier to spot on a 20-line sketch than buried inside 300+ lines that also
runs Wi-Fi and a servo.

```
diagnostics/load_cell_test   →  diagnostics/ultrasonic_test
diagnostics/button_test      →  diagnostics/oled_test (+ i2c_scanner if it fails)
                                        ↓
                    esp32s3_hub.ino  (ESP32-S3 — sensors, servo, Wi-Fi, HTTP,
                                       all on one board)

    esp32_cam.ino  (ESP32-CAM — entirely separate board, own IP, own Wi-Fi
                     connection, flash independently at any point)
```

## Feeder servo (SG90, direct-drive on the ESP32-S3)

The SG90 signal wire goes straight to the ESP32-S3's **GPIO17** — no second
microcontroller, no UART link. Power the SG90 from a separate 5V supply
(not the ESP32-S3's own 3.3V/5V pin — an SG90 can spike current on startup
enough to brown out the board if it shares that rail), with SG90 GND tied
to ESP32-S3 GND (common ground, same rule as everything else on this
board).

Since the SG90 has no feedback of its own, `esp32s3_hub.ino` doesn't time
the servo open — it opens the gate and watches the **load cell's live
weight reading** climb, closing the instant the target grams lands. That
makes portion size self-calibrating against your mechanism's actual flow
rate instead of a fragile `ms-per-gram` constant. A 8-second safety timeout
closes the gate and reports an error if the target is never reached (empty
hopper, jam, stuck gate) — see the "Feed dispensing" comment block at the
top of `esp32s3_hub.ino`.

One thing worth bench-testing before mounting it in the hopper: confirm
`SERVO_OPEN_ANGLE` (90° by default) gives a food flow slow enough to land
close to small gram targets — a very fast-flowing gate can overshoot by
several grams between load-cell polls.

## ESP32-CAM (`esp32_cam/esp32_cam.ino`)

Standard AI-Thinker pin map, no extra wiring beyond the board itself and
its own USB-TTL programmer (§8 below covers programming mode). Fill in
`WIFI_SSID`/`WIFI_PASSWORD` the same way as the hub, flash it via Cloud
Editor the same way (§2), read its IP off Serial Monitor. In the app, add
that IP under **Settings → Feeder Cam** (separate field from the hub's —
this is a different physical board).

Two things it does *not* have real hardware for, handled honestly rather
than faked:
- **Night vision** toggles the onboard white flash LED (GPIO4) — there's
  no IR-cut removal or IR LEDs on this board, so it's not real night
  vision, just the closest real equivalent.
- **Mic** toggle just remembers the on/off flag — the AI-Thinker board has
  no microphone at all. Real audio needs an add-on I2S mic module and
  capture code neither of which are here.

## 1. Checking each remaining sensor

Each folder under `diagnostics/` is a complete, standalone Arduino sketch —
one sensor, one job: prove it's wired right and readable, nothing else.

| Sketch | Confirms | What "working" looks like |
|---|---|---|
| `load_cell_test` | HX711 + load cell | Raw number near 0 when empty, moves when pressed |
| `ultrasonic_test` | HC-SR04 | Distance in cm that tracks your hand moving toward/away |
| `button_test` | Push button | "Button PRESSED" / "released" printed on press/release |
| `oled_test` | 0.96" OLED | Screen shows "PetPulse / OLED OK" |
| `i2c_scanner` | (helper) | Lists I2C addresses found — use if `oled_test` can't find the display |

Flash one, open the Serial Monitor (**115200 baud** for all of these
except `i2c_scanner` which is also 115200), read the comment block at the
top of the file for what to expect, confirm it, move to the next. Each
file's header comment repeats its wiring so you don't have to cross-
reference this doc while you're at the breadboard.

**Load cell needs a real calibration step**, not just a pass/fail: put a
known weight on it, note the raw number, and compute
`raw_reading / known_weight_grams`. You'll plug that into
`LOADCELL_CALIBRATION_FACTOR` in `esp32s3_hub.ino` later — the placeholder
value (420.0) in there is a generic starting point, not your sensor's
real number.

## 2. Dumping code with Arduino Cloud

Quick terminology check, because this is where most confusion comes from:
**Arduino Cloud** bundles two different things:

- **Cloud Editor** — a browser IDE that compiles a sketch and uploads it
  to a board over USB, via a small background program on your computer
  called the **Arduino Create Agent**. This is what you want, for both
  boards below.
- **Arduino IoT Cloud** ("Things", dashboards, cloud variables) — a
  separate, higher-level service for cloud-synced variables/dashboards.
  You don't need it for this project; the Flutter app talks to the
  ESP32-S3 hub directly over your home Wi-Fi (see §4), not through IoT
  Cloud's dashboard/variable-sync layer.

So: **Cloud Editor**, once per board, one at a time (only one board plugged
in and selected at a time — you cannot have both upload sessions active
through one Create Agent connection picker simultaneously).

**One-time setup:**
1. Install the **Arduino Create Agent** for your OS (Arduino Cloud will
   prompt you to install it the first time you open the Editor if it
   isn't running — it needs to stay running in the background whenever
   you upload).
2. In Cloud Editor, open the board/port picker in the top bar.

**Uploading `esp32s3_hub.ino` to the ESP32-S3:**
1. Plug the ESP32-S3 into USB.
2. Board/port picker → search **"esp32"** if it's not already in your
   board list, install the **"esp32 by Espressif Systems"** package (one
   time only), then select your specific board (something like
   "ESP32S3 Dev Module" — pick the closest match to your actual board).
3. Open the Library panel, install: **"HX711"** (by Bogdan Necula),
   **"Adafruit SSD1306"** (installing it will offer "Adafruit GFX Library"
   as a dependency — accept that too), and **"ESP32Servo"** (by Kevin
   Harrington / John K. Bennett — this drives the SG90; the plain `Servo`
   library that ships with AVR boards does not work on ESP32).
4. Open `esp32s3_hub.ino`, fill in your real `WIFI_SSID` /
   `WIFI_PASSWORD`, and your real `LOADCELL_CALIBRATION_FACTOR` /
   `HOPPER_EMPTY_CM` / `HOPPER_FULL_CM` from your sensor testing in §1.
5. Click **Upload** (the arrow icon). Cloud Editor compiles it server-side
   and Create Agent flashes it over your USB cable. Watch the console at
   the bottom for errors.
6. Open the Serial Monitor tab in the editor at **115200 baud** — you
   should see it connect to Wi-Fi and print an IP address
   (`"Connected. IP address: ..."`). Write that IP down, you need it for
   §4.

**Uploading `esp32_cam/esp32_cam.ino` to the ESP32-CAM:** see the "ESP32-CAM"
section above — same Cloud Editor flow, its own separate board/port
selection and its own Wi-Fi credentials.

## 3. Reviewing your wiring plan

Your plan is solid — TX→RX crossing, the level shifter on the 5V→3.3V UART
leg, and keeping MG996R off the logic supplies are all the right calls,
and I haven't changed any GPIO assignment. A few things worth double-
checking before you commit to the breadboard:

- **1k/2k divider math, confirmed correct.** `5V × (2k / (1k+2k)) = 3.33V`
  — comfortably above the ~2.3V "definitely a HIGH" threshold for 3.3V
  logic, comfortably below the 3.3V absolute max. Good ratio, no change
  needed on the HC-SR04 ECHO leg.
- **GPIO15/17 are safe choices on the S3.** ESP32-S3's boot-strapping pins
  are GPIO0, 3, 45, 46 — a different set from the original ESP32, and none
  of your assigned pins (4, 5, 6, 7, 8, 9, 15, 17) are on that list. No
  boot-mode conflicts.
- **HC-SR04 needs real 5V, not "whatever's on the 5V pin."** If your
  ESP32-S3 board only gets its 5V rail powered while plugged into a
  computer's USB (common on smaller dev boards — VIN/5V is sometimes
  only live when driven externally, not just because the board is
  running on 3.3V from a battery), the sensor will silently stop working
  once you move to the power bank. Verify 5V is actually present there
  with a multimeter once you're running off the power bank, not just
  during development over USB.
- **SG90 is much gentler on the power budget than a bigger servo.** A
  typical SG90 draws roughly 100–250mA in normal operation, occasionally
  spiking higher when it starts moving — nowhere near the 1–2.5A an MG996R
  can pull, so brownout risk from the power bank is low. Still worth doing
  both of the cheap, easy things: give it its own 5V supply (not the
  ESP32-S3's 3.3V/5V pin) and a small bulk capacitor (100–470µF
  electrolytic, rated ≥6.3V) across its V+/GND right at the servo, to
  smooth out the startup spike.
- **Common ground, everywhere, always.** ESP32-S3 GND, SG90 supply GND, and
  the power bank's grounds (if it's multiple separate outputs) all need to
  be tied together. A missing ground reference between any two
  interconnected components is the single most common cause of wildly
  wrong sensor readings that "look like" a code bug but aren't.

## 4. Integrating with the Flutter app

`esp32s3_hub.ino` implements a real slice of `app/docs/API_CONTRACT.md` —
`GET /health`, `GET /api/v1/telemetry` (real bowl weight + food level),
and `POST /api/v1/feed/manual` + `GET /api/v1/feed/manual/{id}` (which now
drives the SG90 directly and reports real dispense progress back from the
load cell — see "Feeder servo" above). It deliberately does **not**
implement auth, device pairing, schedule storage, history, alerts, or the
camera endpoints — those stay on `app/mock_server` (or a real cloud relay
later); see the contract doc's architecture section for why. Concretely,
that means the hub trusts anything that reaches it on your LAN — fine for
home Wi-Fi, not something to expose to the internet as-is.

To point the app at your real hub instead of (or alongside) the mock
server:

1. Flash `esp32s3_hub.ino`, get its IP from Serial Monitor (§2).
2. In the app, go to **Settings → Feeder Hub** and enter that IP — the app
   tests it live (`GET /health`) and shows connected/failed right there.
   `ApiService._resolveBaseUrl()` (`app/lib/services/api_service.dart`)
   then tries that local IP first on every telemetry/feed request and only
   falls back to the cloud/mock base URL if it doesn't answer within
   800ms — so once it's set, Home screen telemetry and the Feed Now
   button start hitting your real hardware automatically. Schedule,
   history, alerts, and the camera tab keep talking to `mock_server` (or
   your relay) since the hub doesn't serve those.
3. Press the physical button on the hub, or tap Feed Now in the app —
   either path calls the same `startFeed()` in the hub firmware, opens the
   SG90 directly, and you should see `dispensedGrams` climb in the app's
   feed sheet in near-real-time as the load cell tracks the real weight
   landing in the bowl.

If you want the app to reach the hub from *outside* your home Wi-Fi
(the original "feed while away" goal), that's the cloud-relay piece in
the contract doc that isn't built yet — this hub firmware only answers on
the local network for now.
