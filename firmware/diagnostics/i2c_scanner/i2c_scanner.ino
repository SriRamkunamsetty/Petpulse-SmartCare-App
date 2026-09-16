// PetPulse — I2C scanner
//
// Run this if oled_test doesn't find your display. It scans every I2C
// address and prints which ones respond, so you can confirm the OLED is
// wired correctly (SDA=GPIO8, SCL=GPIO9) and find its real address if it
// isn't the common default (0x3C).

#include <Wire.h>

const int SDA_PIN = 8;
const int SCL_PIN = 9;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Wire.begin(SDA_PIN, SCL_PIN);
  Serial.println("PetPulse: I2C scanner (SDA=GPIO8, SCL=GPIO9)");
}

void loop() {
  int found = 0;
  Serial.println("Scanning...");
  for (byte address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    byte error = Wire.endTransmission();
    if (error == 0) {
      Serial.print("Device found at 0x");
      if (address < 16) Serial.print("0");
      Serial.println(address, HEX);
      found++;
    }
  }
  if (found == 0) {
    Serial.println("No I2C devices found - check SDA/SCL wiring and OLED power.");
  }
  Serial.println("---");
  delay(3000);
}
