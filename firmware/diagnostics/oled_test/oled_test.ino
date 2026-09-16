// PetPulse — 0.96" I2C OLED (SSD1306) diagnostic
//
// Wiring:
//   OLED VCC -> ESP32-S3 3.3V
//   OLED GND -> ESP32-S3 GND
//   OLED SDA -> ESP32-S3 GPIO8
//   OLED SCL -> ESP32-S3 GPIO9
//
// Libraries needed (Arduino Library Manager): "Adafruit SSD1306" and
// "Adafruit GFX Library" (installing the first pulls in the second as a
// dependency). Assumes the common 128x64 SSD1306 panel at I2C address
// 0x3C. If your panel uses a different controller (SH1106) or address
// (0x3D), run i2c_scanner.ino first to confirm the address.
//
// Expected result: the OLED shows "PetPulse" / "OLED OK". If setup() gets
// stuck printing "OLED NOT FOUND", double check SDA/SCL wiring and run
// i2c_scanner.ino to see if the panel shows up at all.

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SDA_PIN 8
#define SCL_PIN 9
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_ADDR 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

void setup() {
  Serial.begin(115200);
  delay(500);
  Wire.begin(SDA_PIN, SCL_PIN);

  Serial.println("PetPulse: OLED diagnostic");

  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println("OLED NOT FOUND at 0x3C. Try OLED_ADDR 0x3D, or run i2c_scanner.ino.");
    while (true) delay(1000);
  }

  Serial.println("OLED found and initialized.");
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("PetPulse");
  display.println("OLED OK");
  display.display();
}

void loop() {
  // Nothing to do — static test screen is enough to confirm the panel works.
}
