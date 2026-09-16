// PetPulse — ESP32-CAM (AI-Thinker) firmware
//
// A separate board from the ESP32-S3 hub, with its own IP — the app talks
// to it directly for camera endpoints (see docs/API_CONTRACT.md "Camera").
// It does not talk to the hub or the UNO at all.
//
// Wiring: none beyond the AI-Thinker board itself and its own USB-TTL
// programmer (see firmware/README.md §2 "ESP32-CAM + TTL programmer" for
// the GPIO0-to-GND-during-upload step). No extra sensors on this board.
//
// Libraries: none to install — `esp_camera.h` ships with the "esp32 by
// Espressif Systems" board package (same one you already installed for
// the hub). WiFi/WebServer are bundled too.
//
// ── Real vs. approximated hardware ──────────────────────────────────────
// - Live stream + snapshot: real, using the actual camera sensor.
// - "Night vision" toggle: this board has no IR-cut removal or IR LEDs —
//   there is no true night vision hardware. This toggles the onboard
//   white flash LED (GPIO4) instead, the closest real equivalent. Don't
//   expect it to work in full darkness like a real IR camera would.
// - "Mic" toggle: the AI-Thinker board has NO microphone at all. This
//   endpoint just remembers the on/off flag so the app's UI doesn't
//   error — it does not enable real audio. Add an I2S mic module and
//   real capture code if you need that for real.
//
// ── Known limitation: single active stream ──────────────────────────────
// /stream is served by writing frames directly to the client inside the
// request handler (matches the app's `http://<cam-ip>/stream` URL with no
// separate port). That blocks this board's main loop for as long as a
// client stays connected — fine for one phone watching at a time (this
// project's use case), but a second simultaneous stream viewer, or a
// snapshot/status request while someone's watching, will wait until the
// stream disconnects.

#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"

// ── Wi-Fi ────────────────────────────────────────────────────────────────
// TODO: fill in your own network before flashing (same network as the hub).
const char *WIFI_SSID = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ── AI-Thinker ESP32-CAM pin map (standard — do not change unless you're
// on a different camera board) ──────────────────────────────────────────
#define PWDN_GPIO_NUM 32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 0
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27
#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 21
#define Y4_GPIO_NUM 19
#define Y3_GPIO_NUM 18
#define Y2_GPIO_NUM 5
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22
#define FLASH_LED_PIN 4

WebServer server(80);
bool micOn = false;
bool nightVisionOn = false;
String lastSnapshotAt = "";

void setup() {
  Serial.begin(115200);
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);

  if (!initCamera()) {
    Serial.println("Camera init FAILED — check wiring/board selection. Halting.");
    while (true) delay(1000);
  }

  connectWiFi();

  server.on("/health", HTTP_GET, []() {
    server.send(200, "application/json", "{\"ok\":true}");
  });
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/api/v1/camera/snapshot", HTTP_GET, handleSnapshot);
  server.on("/api/v1/camera/mic", HTTP_POST, handleMic);
  server.on("/api/v1/camera/night_vision", HTTP_POST, handleNightVision);
  server.on("/api/v1/camera/status", HTTP_GET, handleStatus);
  server.begin();
  Serial.println("ESP32-CAM HTTP server started.");
}

void loop() {
  server.handleClient();
}

bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  // NOTE: if this line fails to compile with "no member named
  // 'pin_sscb_sda'", your esp32-camera version renamed these to
  // pin_sccb_sda / pin_sccb_scl (SCCB is the correct protocol name — SSCB
  // was the older, widely-copied field name). Swap sscb<->sccb here and
  // on the next line if that happens; nothing else needs to change.
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA;  // 640x480
    config.jpeg_quality = 12;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_QVGA;  // 320x240 — no PSRAM, keep it light
    config.jpeg_quality = 15;
    config.fb_count = 1;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("esp_camera_init failed: 0x%x\n", err);
    return false;
  }
  return true;
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(400);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Connected. IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Wi-Fi connect failed - check WIFI_SSID/WIFI_PASSWORD.");
  }
}

// ── HTTP handlers ────────────────────────────────────────────────────────

void handleStream() {
  WiFiClient client = server.client();
  String header = "HTTP/1.1 200 OK\r\n";
  header += "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n";
  header += "Cache-Control: no-cache\r\n\r\n";
  client.print(header);

  while (client.connected()) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
      delay(50);
      continue;
    }
    client.print("--frame\r\n");
    client.print("Content-Type: image/jpeg\r\n");
    client.printf("Content-Length: %u\r\n\r\n", fb->len);
    client.write(fb->buf, fb->len);
    client.print("\r\n");
    esp_camera_fb_return(fb);
    if (!client.connected()) break;
    delay(50);  // ~20fps cap — plenty for a bowl-side cam, easy on Wi-Fi
  }
}

void handleSnapshot() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    server.send(503, "application/json", "{\"error\":\"camera capture failed\"}");
    return;
  }
  lastSnapshotAt = isoTimestamp();
  server.sendHeader("Content-Type", "image/jpeg");
  server.setContentLength(fb->len);
  server.send(200);
  WiFiClient client = server.client();
  client.write(fb->buf, fb->len);
  esp_camera_fb_return(fb);
}

void handleMic() {
  // See header comment — no mic hardware, this just remembers the flag.
  String body = server.arg("plain");
  micOn = body.indexOf("true") != -1;
  server.send(204);
}

void handleNightVision() {
  String body = server.arg("plain");
  nightVisionOn = body.indexOf("true") != -1;
  digitalWrite(FLASH_LED_PIN, nightVisionOn ? HIGH : LOW);
  server.send(204);
}

void handleStatus() {
  String json = "{";
  json += "\"signal\":\"" + String(WiFi.status() == WL_CONNECTED ? "strong" : "offline") + "\",";
  json += "\"last_snapshot_at\":" + (lastSnapshotAt.isEmpty() ? "null" : "\"" + lastSnapshotAt + "\"");
  json += "}";
  server.send(200, "application/json", json);
}

String isoTimestamp() {
  time_t now;
  time(&now);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buf);
}
