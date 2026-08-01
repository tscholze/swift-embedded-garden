/// Board-level wiring defaults for the SSD1306 OLED display.
///
/// These values are a board-wiring transform of the display's firmware
/// requirements and remain device-specific rather than transport-specific.
struct SSD1306Configuration {
  /// The seven-bit I2C address used by the SSD1306 controller.
  let i2cAddress: UInt8

  /// The RP2040 GPIO assigned to I2C0 SDA.
  let sdaPin: UInt32

  /// The RP2040 GPIO assigned to I2C0 SCL.
  let sclPin: UInt32

  /// The requested I2C clock rate in hertz.
  let i2cClockHz: UInt32

  /// Creates an SSD1306 wiring configuration.
  ///
  /// - Parameters:
  ///   - i2cAddress: Seven-bit display address. `0x3C` is the common
  ///     Elegoo default; some otherwise compatible modules use `0x3D`.
  ///   - sdaPin: An I2C0-capable GPIO used for SDA. The Pico default is GP4 or GP12.
  ///   - sclPin: The matching I2C0-capable GPIO used for SCL. The Pico default is GP5 or GP13.
  ///   - i2cClockHz: Bus frequency. The supplied driver supports up to 400 kHz.
  init(
    i2cAddress: UInt8 = 0x3c,
    sdaPin: UInt32 = 12,
    sclPin: UInt32 = 13,
    i2cClockHz: UInt32 = 400_000
  ) {
    self.i2cAddress = i2cAddress
    self.sdaPin = sdaPin
    self.sclPin = sclPin
    self.i2cClockHz = i2cClockHz
  }
}
