# PetPulse — Flutter app

A production-structured Flutter implementation of the PetPulse Smart Care
design (`project/PetPulse App.dc.html` — see `chats/chat1.md` for the
original design conversation this was built from). Home/dashboard (bowl
weight, food level, bowl height, real next-feeding time), live ESP32-CAM
preview, day-wise feeding schedule with a real time picker, manual feed,
history/alerts, an AI Insights screen (real Gemini API calls using the
pet's actual profile and data), settings (real connected Wi-Fi name, hub
and camera IP connection), and a full onboarding flow (pet profile →
health → feeder pairing).

Real ESP32-S3/ESP32-CAM firmware lives in `../firmware/` (sibling to
this `app/` directory) — see `firmware/README.md` for wiring, flashing,
and how it connects to this app.

Every screen is a real REST client against the contract in
[`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) — there's no hardcoded mock
data in the UI layer. `mock_server/` is a real, runnable implementation of
that contract so the app has something to talk to today, before real ESP32
firmware exists.

## Run it

```bash
# 1. Start the mock backend (implements docs/API_CONTRACT.md)
cd mock_server && npm install && npm start   # http://<your-ip>:4000

# 2. Point the app at it and run
cd .. 
flutter pub get
flutter run
```

On first launch the app registers an anonymous per-install account against
whatever `ApiService.defaultCloudBaseUrl` points at
(`lib/services/api_service.dart`) — change that constant, or call
`ApiService.setCloudBaseUrl()`, to point at your mock server's LAN address
(a phone/emulator can't reach `localhost` on your dev machine — use your
machine's LAN IP) or a deployed relay.

`flutter analyze`, `flutter test`, and `dart format` all pass clean.

## Architecture

```
lib/
  models/       Pet, Device, ScheduleEntry, FeedingEvent, AlertItem, Telemetry, PpConnectivity
  services/     ApiService (REST client), PollingService (telemetry loop), NotificationService
  state/        AppState (post-onboarding app state), OnboardingState
  screens/      one file per tab + onboarding/ + sheets/
  widgets/      shared UI matching the Organic design system (glass, cards, buttons, MjpegView)
  theme/        colors/type/spacing tokens ported 1:1 from styles.css
docs/API_CONTRACT.md   the REST contract everything above is written against
mock_server/           a real Node/Express implementation of that contract
```

State management is `provider` with plain `ChangeNotifier`s — no code
generation, easy to trace. `AppState` owns everything after onboarding
(pet, devices, schedule, telemetry, alerts, camera controls); `PollingService`
polls `/api/v1/telemetry` on a 5s/30s cadence with backoff, feeding
`AppState.telemetry` and, through it, the connectivity banner.

## Why a cloud relay + local-first REST (not MQTT/BLE)

The chat that produced the design settled on **Wi-Fi + REST/HTTP polling**.
Kept that, but "feed the pet while away from home" needs devices reachable
from outside the home network too — an ESP32 behind a home router has no
public IP. `ApiService._resolveBaseUrl()` tries the paired hub's local IP
first (low latency on the home Wi-Fi) and falls back to a cloud relay
otherwise — but **only** for the handful of endpoints the hub firmware
actually implements (telemetry, feed). Everything else (schedule, alerts,
history, pet profile) always goes to the cloud/mock base, since the hub
doesn't store that data — routing those through the hub used to 404 and
silently undo optimistic UI updates. Full writeup: `docs/API_CONTRACT.md`.

The camera is a **separate physical board with its own IP** — camera
calls never go through the hub or cloud resolution at all, they go
straight to whatever IP is set in Settings → Feeder Cam.

## What's real vs. what's stubbed

**Real:**
- Every screen reads/writes through `ApiService` — REST calls, no mock
  data baked into widgets.
- `mock_server/` is a working server: auth, pet profile, device pairing
  (simulated discovery), telemetry (incl. `bowl_height_cm`), manual feed
  with animated dispense progress, schedule CRUD, history, alerts, and an
  actual MJPEG camera stream (`mock_server/camera.js` synthesizes and
  encodes real JPEG frames with `jpeg-js` — no bundled image asset). It
  can also stand in as a "cam" device — point Settings → Feeder Cam at
  `<your-machine-ip>:4000` to test the Camera tab without real hardware.
- `MjpegView` (`lib/widgets/mjpeg_view.dart`) is a from-scratch MJPEG
  decoder (scans for JPEG SOI/EOI markers), not a mocked video widget.
- `../firmware/esp32s3_hub/esp32s3_hub.ino` and `esp32_cam.ino` are real,
  flashable firmware — not just a spec. Real load cell/ultrasonic sensor
  readings, real SG90 servo dispensing (driven directly by the ESP32-S3,
  no separate feeder microcontroller), and a real camera stream, once
  flashed and connected via Settings.
- `GeminiService` (`lib/services/gemini_service.dart`) calls the real
  Gemini `generateContent` REST API with the pet's actual profile,
  telemetry, schedule and history — you provide your own API key (from
  aistudio.google.com), entered on the AI Insights screen and stored only
  on-device.
- `WifiInfoService` reads the phone's actual connected Wi-Fi SSID via
  `network_info_plus` (Android needs location permission for this — an OS
  restriction; iOS needs a paid-account entitlement PetPulse can't grant
  from here, so it falls back to "Unavailable" there).
- Local push notifications fire for real when `AppState` sees a new
  unread alert (`flutter_local_notifications`).

**Stubbed / needs more hardware or infra to finish:**
- **Cloud relay deployment** — `mock_server` runs in-memory on one
  machine; a real deployment needs a database, the hub↔relay push/poll
  side documented in the contract, and TLS.
- **Device pairing against real hardware** — the Settings pairing sheet
  still talks to `mock_server`'s simulated discovery; the real hub/cam
  don't implement the pairing endpoints (out of scope — see
  firmware/README.md), so for now you enter their IPs directly instead.
- **Push notifications while fully closed** need FCM/APNs wired
  server-side; what's here only fires while the app process is alive.
- **App icon** is still the Flutter default — swap `android/app/src/main/res/mipmap-*`
  and `ios/Runner/Assets.xcassets/AppIcon.appiconset`.

## Before shipping to the stores

- [ ] Real app icon + splash screen
- [ ] Replace `ApiService.defaultCloudBaseUrl` with your deployed relay's HTTPS URL
- [ ] Android: `android:usesCleartextTraffic="true"` is set so the app can
      reach the hub's dynamic LAN IP over plain HTTP — narrow this if you
      end up with a static local address space, or drop it once
      LAN-direct mode isn't needed
- [ ] iOS: `NSAllowsLocalNetworking` / `NSLocalNetworkUsageDescription` are
      set for the same reason (`ios/Runner/Info.plist`)
- [ ] Code signing (Android keystore / iOS provisioning profile) — not
      set up here
- [ ] Privacy policy + App Store / Play Store listing content (the app
      talks to IoT devices and a backend — both stores require a privacy
      policy URL)
- [ ] FCM/APNs for background push, if you want alerts to arrive while
      the app is closed
