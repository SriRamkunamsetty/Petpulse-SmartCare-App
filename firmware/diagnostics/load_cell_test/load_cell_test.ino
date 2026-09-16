// PetPulse — Load cell (HX711) diagnostic
//
// Run this FIRST, by itself, before touching the full hub firmware. It only
// checks one thing: is the HX711 wired correctly and readable.
//
// Wiring (matches the ESP32-S3 pin table in firmware/README.md):
//   HX711 VCC -> ESP32-S3 3.3V
//   HX711 GND -> ESP32-S3 GND
//   HX711 DT  -> ESP32-S3 GPIO4
//   HX711 SCK -> ESP32-S3 GPIO5
//   Load cell E+/E-/A+/A- -> HX711 E+/E-/A+/A- (use your load cell's own
//   labels/datasheet, not wire color — colors aren't standardized).
//
// Library needed (Arduino Library Manager): "HX711" by Bogdan Necula
// (bogde/HX711). In Arduino Cloud Editor: Libraries panel -> search "HX711"
// -> Include.
//
// Expected result: open Serial Monitor at 115200 baud. With the bowl empty
// and still, "Raw reading" should hover near 0 (±a few hundred is normal
// noise) after tare. Pressing on the load cell should move the number up;
// releasing should bring it back down. If you see nothing, or a value stuck
// at a huge/garbage number, it's a wiring problem — check DT/SCK pins and
// the E+/E-/A+/A- wiring on the load cell side first.

#include "HX711.h"

const int LOADCELL_DOUT_PIN = 4;
const int LOADCELL_SCK_PIN = 5;

HX711 scale;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("PetPulse: HX711 load cell diagnostic");

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);

  if (!scale.is_ready()) {
    Serial.println("HX711 NOT FOUND. Check DT=GPIO4, SCK=GPIO5, VCC, GND wiring.");
    return;
  }

  Serial.println("HX711 found. Keep the bowl EMPTY and still for taring...");
  delay(1500);
  scale.set_scale();  // raw units for now — we calibrate grams later
  scale.tare();
  Serial.println("Tare done. Raw readings below should sit near 0 with nothing on the load cell.");
  Serial.println("Place a KNOWN weight on it and note the raw number — you'll need it to");
  Serial.println("calculate the calibration factor for the real hub firmware.");
}

void loop() {
  if (!scale.is_ready()) {
    Serial.println("HX711 not responding - check wiring.");
    delay(1000);
    return;
  }
  long raw = scale.get_units(5);
  Serial.print("Raw reading: ");
  Serial.println(raw);
  delay(500);
}
