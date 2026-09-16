# PetPulse app ↔ IoT contract

This is the contract the Flutter app in `app/lib` is written against. It's
implemented for real by `app/mock_server` (Node/Express) for development, and
is what the ESP32 firmware (hub + cam) needs to implement to work with the
app unmodified.

## Why a cloud relay, not just LAN REST

The original ask is "feed the pet while I'm away from home." An ESP32 sitting
behind a home router has no public IP and can't accept inbound connections
from a phone on cellular data — so a pure "phone talks directly to the ESP32
over REST" design only works when the phone is on the same Wi-Fi network.

The contract below keeps the **transport the chat settled on (Wi-Fi +
REST/HTTP polling, no MQTT/BLE)**, but adds one piece of real architecture
needed to make "away from home" actually work:

- The **hub (ESP32-S3)** holds a persistent outbound HTTPS connection to a
  small cloud relay and pushes telemetry / long-polls for pending commands.
  It never needs an inbound port opened on the home router.
- The **app** always talks REST to the relay's public base URL. When the
  app detects it's on the same LAN as the hub (`GET {local_base}/health`
  succeeds within 800ms), it talks directly to the hub instead, for lower
  latency — same endpoints, different base URL. This is `ApiService`'s
  `_resolveBaseUrl()`.
- The **cam (ESP32-CAM)** serves its MJPEG stream directly on the LAN
  (`GET /stream`) for low-latency local viewing, and the relay proxies a
  throttled version of the same stream for remote viewing.

Everything below is one REST contract; only the base URL differs between
"local hub" and "cloud relay" — the relay forwards 1:1 to the hub for
everything except the camera proxy.

## Auth

`POST /api/v1/auth/register` `{email, password}` → `{token, user_id}`
`POST /api/v1/auth/login` `{email, password}` → `{token, user_id}`

All other endpoints require `Authorization: Bearer <token>`.

## Pet profile

`GET /api/v1/pet` → `Pet`
`PUT /api/v1/pet` `Pet` → `Pet`

```json
{
  "name": "Milo", "breed": "Corgi",
  "age_value": 2, "age_unit": "yrs",
  "weight_value": 12, "weight_unit": "kg",
  "health_conditions": ["Diabetes"], "notes": "sensitive stomach"
}
```

## Device pairing

`POST /api/v1/devices/pair/start` → `{session_id}` — hub broadcasts on
local network / relay watches for a new device announcing itself.
`GET /api/v1/devices/pair/status?session_id=` → `{state: "searching"|"found"|"failed", device: Device?}`
`POST /api/v1/devices/pair/confirm` `{session_id}` → `Device`

`GET /api/v1/devices` → `Device[]`

```json
{ "id": "hub-1", "name": "ESP32-S3 Main Hub", "kind": "hub",
  "status": "online", "battery_pct": 82, "meta": "Controller",
  "ip_address": "192.168.1.42" }
```

`kind`: `hub | cam | load_cell | ultrasonic`. `status`: `online | offline | low_battery`.

## Telemetry (polled)

`GET /api/v1/telemetry` → `Telemetry`

```json
{
  "bowl_weight_grams": 12.5, "food_level_pct": 78,
  "next_feed_time": "6:00 PM", "next_feed_grams": 45,
  "connectivity": "online",
  "last_updated": "2026-09-16T12:00:00Z",
  "last_refilled": "6:00 PM"
}
```

`connectivity`: `online | device_offline | sensor_error | low_battery | cloud_unreachable`.
The app treats an HTTP/network failure to reach *either* base URL as
`cloud_unreachable` locally — the server doesn't need to send that value
except to describe its own last-known relay state.

**Polling cadence:** 5s while Home or Camera tab is foregrounded, 30s
elsewhere, paused when the app is backgrounded. On failure: retry with
1s/2s/4s/8s backoff capped at 30s, and surface `cloud_unreachable` after two
consecutive failures.

## Manual feed

`POST /api/v1/feed/manual` `{grams}` → `{job_id}`
`GET /api/v1/feed/manual/{job_id}` → `{status: "dispensing"|"done"|"error", dispensed_grams}`

App polls the job every 180ms (matches the prototype's dispense animation
cadence) until `done` or `error`.

## Schedule

`GET /api/v1/schedule` → `ScheduleEntry[]` (all days)
`POST /api/v1/schedule` `{day, time, grams}` → `ScheduleEntry` — one call per
selected day when adding a multi-day entry.
`PATCH /api/v1/schedule/{id}` `{enabled}` → `ScheduleEntry`
`DELETE /api/v1/schedule/{id}` → `204`

```json
{ "id": "sch_1", "day": "Mon", "time": "8:00 AM", "grams": 40, "enabled": true }
```

## History

`GET /api/v1/history?range=week` →

```json
{
  "bars": [{"label": "Mon", "grams": 76}, ...],
  "events": [{"id": "ev_1", "timestamp": "...", "grams": 45,
              "result": "completed", "note": ""}]
}
```

`result`: `completed | skipped | failed`.

## Alerts

`GET /api/v1/alerts` → `AlertItem[]`
`POST /api/v1/alerts/{id}/read` → `204`

Server-generated on: low food level (<15%), reduced intake (>10% below
7-day average), feeding complete, device online/offline transitions.

## Camera (ESP32-CAM)

`GET /stream` (on the cam's own local base URL, or proxied by the relay at
`GET /api/v1/camera/stream`) — `multipart/x-mixed-replace; boundary=frame`
MJPEG, ~720p. The app's `MjpegView` widget parses this directly; no extra
package.
`GET /api/v1/camera/snapshot` → single `image/jpeg`.
`POST /api/v1/camera/mic` `{on: bool}` → `204`
`POST /api/v1/camera/night_vision` `{on: bool}` → `204`
`GET /api/v1/camera/status` → `{signal: "strong"|"weak"|"offline", last_snapshot_at}`

## Error → UI state mapping (`ApiException`)

| Condition | `PpConnectivity` |
|---|---|
| Both local and relay base URLs unreachable | `cloudUnreachable` |
| Relay reachable, hub reports itself offline | `deviceOffline` |
| Hub online, load-cell/ultrasonic readings stale/null | `sensorError` |
| Hub `battery_pct` < 15 | `lowBattery` |
| none of the above | `online` |

## What's real vs. stubbed in this handoff

- The Flutter app is a full REST client against this contract — no mock
  data hardcoded in the UI layer.
- `app/mock_server` is a real, runnable implementation of this contract
  (in-memory) so the app has something to talk to today.
- ESP32 firmware (hub + cam) is **not** in this repo — an embedded engineer
  implements this same contract in Arduino/ESP-IDF. `mock_server` is the
  spec to build against.
- Push notifications for alerts are wired locally
  (`flutter_local_notifications`, fired when `AppState` sees a new unread
  `AlertItem`); real push delivery while the app is fully closed needs
  FCM/APNs wired server-side, which isn't set up here.
