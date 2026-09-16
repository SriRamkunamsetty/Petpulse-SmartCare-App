// PetPulse — ESP32-S3 main hub firmware
//
// Only flash this AFTER each sensor has passed its own diagnostic sketch in
// ../diagnostics/. This combines all of them plus Wi-Fi + a small HTTP
// server that implements the subset of docs/API_CONTRACT.md this hub is
// responsible for, and drives the SG90 feeder servo directly — there is no
// separate Arduino UNO in this build.
//
// ── What this hub does and does NOT do ──────────────────────────────────
// DOES:
//   - Reads the load cell (bowl weight) and ultrasonic sensor (food level)
//   - Serves GET /health and GET /api/v1/telemetry
//   - Serves POST /api/v1/feed/manual and GET /api/v1/feed/manual/{id},
//     driving the SG90 directly and using the load cell's own weight
//     reading to know when the target has been dispensed (see
//     "Feed dispensing" below) — no second microcontroller involved
//   - Drives the OLED status display and reacts to the physical button
// DOES NOT (left to the cloud relay / mock_server — see docs/API_CONTRACT.md):
//   - Auth, device pairing, schedule storage, history, alerts, camera
//   - This firmware does not check the Authorization header at all, since
//     it's meant to be reached only on your trusted home LAN once the app
//     already has the hub's IP (see firmware/README.md "connecting the
//     hub to the Flutter app" for how the app finds this IP).
//
// ── Pin map (do not change without updating firmware/README.md too) ────
//   GPIO4  = HX711 DT        GPIO7  = HC-SR04 TRIG
//   GPIO5  = HX711 SCK       GPIO15 = HC-SR04 ECHO (via 1k/2k divider)
//   GPIO6  = push button     GPIO8  = OLED SDA
//   GPIO17 = SG90 signal     GPIO9  = OLED SCL
//
// Libraries needed: HX711 (bogde), Adafruit GFX + Adafruit SSD1306,
// ESP32Servo (Kevin Harrington / John K. Bennett).
// WiFi/WebServer/Wire are bundled with the ESP32 Arduino core.
//
// ── Feed dispensing ──────────────────────────────────────────────────────
// The SG90 has no position/torque feedback of its own, so instead of timing
// the servo open like a UNO-relay build would, this hub opens the gate and
// watches the load cell's live bowlWeightGrams climb in real time, closing
// the gate the instant the target is reached — self-calibrating against
// whatever your mechanism's real flow rate is. FEED_TIMEOUT_MS is a safety
// backstop (empty hopper, jam, or a stuck gate) so a feed job can never run
// forever; tune SERVO_OPEN_ANGLE if food flow is too fast/slow to hit small
// gram targets precisely.

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "HX711.h"
#include <ESP32Servo.h>
#include <time.h>
#include <string.h>

// ── Wi-Fi ────────────────────────────────────────────────────────────────
// TODO: fill in your own network before flashing.
const char *WIFI_SSID = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ── Pins ─────────────────────────────────────────────────────────────────
const int HX711_DOUT_PIN = 4;
const int HX711_SCK_PIN = 5;
const int BUTTON_PIN = 6;
const int TRIG_PIN = 7;
const int OLED_SDA_PIN = 8;
const int OLED_SCL_PIN = 9;
const int ECHO_PIN = 15;
const int SERVO_PIN = 17;  // SG90 signal (freed from the old UNO UART link)

// ── Calibration — measure these for YOUR hardware ──────────────────────
// From load_cell_test.ino: raw_reading_with_known_weight / known_weight_g.
const float LOADCELL_CALIBRATION_FACTOR = 420.0;
// From ultrasonic_test.ino: distance (cm) from the sensor to the hopper
// floor when EMPTY, and to the food surface when FULL.
const float HOPPER_EMPTY_CM = 20.0;
const float HOPPER_FULL_CM = 3.0;
// Physical override portion size when the button is pressed.
const int BUTTON_FEED_GRAMS = 45;

// SG90 angles for your gate mechanism — calibrate on the bench: 0 degrees
// is a common "closed" rest angle, but confirm nothing binds before relying
// on it unattended.
const int SERVO_CLOSED_ANGLE = 0;
const int SERVO_OPEN_ANGLE = 90;
// Safety backstop: if the load cell never sees the target weight land within
// this long (empty hopper, jam, gate stuck), stop and report an error rather
// than holding the gate open indefinitely.
const unsigned long FEED_TIMEOUT_MS = 8000;

HX711 scale;
WebServer server(80);
Adafruit_SSD1306 display(128, 64, &Wire, -1);
Servo feederServo;

float bowlWeightGrams = 0;
int foodLevelPct = 0;
// Raw ultrasonic reading, reported to the app separately from foodLevelPct
// as "bowl_height_cm" — see docs/API_CONTRACT.md.
float lastDistanceCm = 0;
bool sensorError = false;
bool oledOk = false;
int lastButtonState = HIGH;

struct FeedJob {
  String id = "";
  int targetGrams = 0;
  int dispensedGrams = 0;
  String status = "done";  // "dispensing" | "done" | "error"
  float startWeightGrams = 0;
  unsigned long startedAtMs = 0;
};
FeedJob activeJob;

// ── Setup ────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);

  pinMode(BUTTON_PIN, INPUT_PULLUP);

  feederServo.attach(SERVO_PIN);
  feederServo.write(SERVO_CLOSED_ANGLE);

  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  oledOk = display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  if (oledOk) {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    showStatus("Starting...");
  } else {
    Serial.println("OLED not found at boot - continuing without it.");
  }

  scale.begin(HX711_DOUT_PIN, HX711_SCK_PIN);
  if (scale.is_ready()) {
    scale.set_scale(LOADCELL_CALIBRATION_FACTOR);
    scale.tare();
  } else {
    Serial.println("HX711 not found at boot.");
  }

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  connectWiFi();

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  server.on("/health", HTTP_GET, handleHealth);
  server.on("/api/v1/telemetry", HTTP_GET, handleTelemetry);
  server.on("/api/v1/feed/manual", HTTP_POST, handleFeedManual);
  server.onNotFound(handleNotFound);  // catches /api/v1/feed/manual/{id}
  server.begin();
  Serial.println("HTTP server started.");
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  showStatus("Connecting WiFi...");
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(400);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("Connected. IP address: ");
    Serial.println(WiFi.localIP());
    showStatus(WiFi.localIP().toString());
  } else {
    Serial.println();
    Serial.println("Wi-Fi connect failed - check WIFI_SSID/WIFI_PASSWORD.");
    showStatus("WiFi FAILED");
  }
}

// ── Main loop ────────────────────────────────────────────────────────────

unsigned long lastSensorReadMs = 0;
unsigned long lastOledUpdateMs = 0;

void loop() {
  server.handleClient();
  handleButton();
  updateFeedProgress();

  if (millis() - lastSensorReadMs > 1000) {
    lastSensorReadMs = millis();
    readSensors();
  }
  if (millis() - lastOledUpdateMs > 1000) {
    lastOledUpdateMs = millis();
    updateOledSummary();
  }
}

void readSensors() {
  bool ok = true;

  if (scale.is_ready()) {
    bowlWeightGrams = scale.get_units(3);
    if (bowlWeightGrams < 0) bowlWeightGrams = 0;
  } else {
    ok = false;
  }

  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration == 0) {
    ok = false;
  } else {
    lastDistanceCm = duration * 0.0343f / 2.0f;
    float pct = (HOPPER_EMPTY_CM - lastDistanceCm) / (HOPPER_EMPTY_CM - HOPPER_FULL_CM) * 100.0f;
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    foodLevelPct = (int)pct;
  }

  sensorError = !ok;
}

void handleButton() {
  int state = digitalRead(BUTTON_PIN);
  if (state == LOW && lastButtonState == HIGH) {
    if (activeJob.status != "dispensing") {
      startFeed(BUTTON_FEED_GRAMS);
    }
  }
  lastButtonState = state;
}

void updateOledSummary() {
  if (!oledOk) return;  // begin() failed at boot
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("PetPulse Hub");
  display.print("Bowl: ");
  display.print(bowlWeightGrams, 1);
  display.println("g");
  display.print("Food: ");
  display.print(foodLevelPct);
  display.println("%");
  display.println(WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : "WiFi: offline");
  if (sensorError) display.println("SENSOR ERROR");
  display.display();
}

void showStatus(const String &line) {
  if (!oledOk) return;
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("PetPulse Hub");
  display.println(line);
  display.display();
}

// ── SG90 feeder servo (direct-drive, no second microcontroller) ────────
// startFeed() opens the gate immediately and returns — the actual close
// happens later from updateFeedProgress(), called every loop() iteration,
// once the load cell reports the target weight has landed (or the safety
// timeout trips). This keeps the HTTP server responsive instead of
// blocking inside the request handler for the whole dispense.

void startFeed(int grams) {
  activeJob.id = String(millis());
  activeJob.targetGrams = grams;
  activeJob.dispensedGrams = 0;
  activeJob.status = "dispensing";
  activeJob.startWeightGrams = bowlWeightGrams;
  activeJob.startedAtMs = millis();
  feederServo.write(SERVO_OPEN_ANGLE);
}

void updateFeedProgress() {
  if (activeJob.status != "dispensing") return;

  float dispensed = bowlWeightGrams - activeJob.startWeightGrams;
  if (dispensed < 0) dispensed = 0;
  activeJob.dispensedGrams = (int)dispensed;

  bool reachedTarget = dispensed >= activeJob.targetGrams;
  bool timedOut = millis() - activeJob.startedAtMs > FEED_TIMEOUT_MS;
  if (!reachedTarget && !timedOut) return;

  feederServo.write(SERVO_CLOSED_ANGLE);
  if (reachedTarget) {
    activeJob.dispensedGrams = activeJob.targetGrams;
    activeJob.status = "done";
  } else {
    // Timed out short of the target — hopper empty, jam, or gate stuck.
    activeJob.status = "error";
  }
}

// ── HTTP handlers ────────────────────────────────────────────────────────

String isoTimestamp() {
  time_t now;
  time(&now);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buf);
}

void handleHealth() {
  server.send(200, "application/json", "{\"ok\":true}");
}

void handleTelemetry() {
  String connectivity = sensorError ? "sensor_error" : "online";
  String json = "{";
  json += "\"bowl_weight_grams\":" + String(bowlWeightGrams, 1) + ",";
  json += "\"food_level_pct\":" + String(foodLevelPct) + ",";
  json += "\"bowl_height_cm\":" + String(lastDistanceCm, 1) + ",";
  json += "\"next_feed_time\":\"--:--\",";  // schedule lives in the app/relay, not the hub
  json += "\"next_feed_grams\":0,";
  json += "\"connectivity\":\"" + connectivity + "\",";
  json += "\"last_updated\":\"" + isoTimestamp() + "\",";
  json += "\"last_refilled\":\"\"";
  json += "}";
  server.send(200, "application/json", json);
}

// Very small hand-rolled JSON body parser — good enough for a single
// integer field like {"grams": 45}. Swap for ArduinoJson if this endpoint
// grows more fields.
int extractIntField(const String &body, const String &field) {
  int keyIndex = body.indexOf("\"" + field + "\"");
  if (keyIndex == -1) return -1;
  int colonIndex = body.indexOf(':', keyIndex);
  if (colonIndex == -1) return -1;
  int i = colonIndex + 1;
  while (i < (int)body.length() && (body[i] == ' ')) i++;
  int start = i;
  while (i < (int)body.length() && isDigit(body[i])) i++;
  if (i == start) return -1;
  return body.substring(start, i).toInt();
}

void handleFeedManual() {
  if (activeJob.status == "dispensing") {
    server.send(409, "application/json", "{\"error\":\"feed already in progress\"}");
    return;
  }
  int grams = extractIntField(server.arg("plain"), "grams");
  if (grams <= 0) {
    server.send(400, "application/json", "{\"error\":\"grams must be a positive integer\"}");
    return;
  }
  startFeed(grams);
  server.send(200, "application/json", "{\"job_id\":\"" + activeJob.id + "\"}");
}

void handleFeedStatus(const String &jobId) {
  if (jobId != activeJob.id) {
    server.send(404, "application/json", "{\"error\":\"unknown job\"}");
    return;
  }
  String json = "{";
  json += "\"status\":\"" + activeJob.status + "\",";
  json += "\"dispensed_grams\":" + String(activeJob.dispensedGrams);
  json += "}";
  server.send(200, "application/json", json);
}

const char *FEED_STATUS_PREFIX = "/api/v1/feed/manual/";

void handleNotFound() {
  String uri = server.uri();
  if (server.method() == HTTP_GET && uri.startsWith(FEED_STATUS_PREFIX)) {
    handleFeedStatus(uri.substring(strlen(FEED_STATUS_PREFIX)));
    return;
  }
  server.send(404, "application/json", "{\"error\":\"not found\"}");
}
