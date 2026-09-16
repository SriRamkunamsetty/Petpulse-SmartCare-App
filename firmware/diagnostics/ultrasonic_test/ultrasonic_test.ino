// PetPulse — Ultrasonic (HC-SR04) diagnostic
//
// Wiring (matches firmware/README.md pin table):
//   HC-SR04 VCC  -> 5V
//   HC-SR04 GND  -> GND
//   HC-SR04 TRIG -> ESP32-S3 GPIO7        (direct — TRIG is an input to the
//                                          sensor, 3.3V from the ESP32 is a
//                                          valid trigger, no divider needed)
//   HC-SR04 ECHO -> voltage divider (1k/2k) -> ESP32-S3 GPIO15
//                   (ECHO is 5V from the sensor — do NOT connect it to the
//                   ESP32-S3 directly, that pin is not 5V tolerant)
//
// No library needed — this uses plain pulseIn().
//
// Expected result: open Serial Monitor at 115200 baud. Hold your hand
// roughly 10-30cm from the sensor and move it — the printed distance
// should track your hand. "No echo received" repeatedly means: check the
// TRIG/ECHO wiring, the divider resistors, and that VCC is actually on 5V
// (HC-SR04 does not work reliably on 3.3V).

const int TRIG_PIN = 7;
const int ECHO_PIN = 15;

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  digitalWrite(TRIG_PIN, LOW);
  Serial.println("PetPulse: HC-SR04 ultrasonic diagnostic");
}

void loop() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  // 30ms timeout ~= 5m max range; pulseIn returns 0 on timeout.
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);

  if (duration == 0) {
    Serial.println("No echo received - check wiring/power, or nothing in range.");
  } else {
    float distanceCm = duration * 0.0343f / 2.0f;
    Serial.print("Distance: ");
    Serial.print(distanceCm);
    Serial.println(" cm");
  }
  delay(400);
}
