// PetPulse — Push button diagnostic
//
// Wiring:
//   Button -> ESP32-S3 GPIO6
//   Button -> GND
//   (INPUT_PULLUP means we don't need an external resistor: the pin reads
//   HIGH when open, and LOW when the button connects it to GND.)
//
// Expected result: open Serial Monitor at 115200 baud. Nothing should print
// until you press the button, then "Button PRESSED", then "Button
// released" when you let go. If it prints repeatedly/randomly with nothing
// pressed, check the GND connection and that you're on GPIO6.

const int BUTTON_PIN = 6;

void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.println("PetPulse: push button diagnostic - press the button");
}

void loop() {
  static int lastState = HIGH;
  static unsigned long lastChangeMs = 0;

  int state = digitalRead(BUTTON_PIN);
  // Simple debounce: ignore changes within 30ms of the last one.
  if (state != lastState && millis() - lastChangeMs > 30) {
    lastState = state;
    lastChangeMs = millis();
    Serial.println(state == LOW ? "Button PRESSED" : "Button released");
  }
}
