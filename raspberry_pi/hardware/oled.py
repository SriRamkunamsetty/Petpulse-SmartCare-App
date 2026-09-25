"""SSD1306 128x64 OLED status display — I2C.

Wiring: standard I2C (SDA -> Pi GPIO2 / physical pin 3, SCL -> Pi GPIO3 /
physical pin 5, VCC -> 3.3V, GND -> GND). Enable I2C first:
`sudo raspi-config` -> Interface Options -> I2C -> enable, then reboot.
"""
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306


class OledDisplay:
    def __init__(self, port: int, address: int):
        self._ok = False
        self._device = None
        try:
            serial = i2c(port=port, address=address)
            self._device = ssd1306(serial)
            self._ok = True
        except Exception:
            # Missing/misconfigured OLED shouldn't take the rest of the hub
            # down — same "continue without it" behavior as the old
            # firmware's `oledOk` flag.
            pass

    @property
    def ok(self) -> bool:
        return self._ok

    def show_status(self, line: str):
        if not self._ok:
            return
        with canvas(self._device) as draw:
            draw.text((0, 0), "PetPulse Hub", fill="white")
            draw.text((0, 14), line, fill="white")

    def show_summary(
        self, bowl_weight_g: float, food_pct: int, ip: str, sensor_error: bool
    ):
        if not self._ok:
            return
        with canvas(self._device) as draw:
            draw.text((0, 0), "PetPulse Hub", fill="white")
            draw.text((0, 14), f"Bowl: {bowl_weight_g:.1f}g", fill="white")
            draw.text((0, 26), f"Food: {food_pct}%", fill="white")
            draw.text((0, 38), ip or "Wi-Fi: offline", fill="white")
            if sensor_error:
                draw.text((0, 50), "SENSOR ERROR", fill="white")
