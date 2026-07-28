/// Board-level wiring defaults for the four-pin Elegoo 0.96-inch SSD1306 OLED.
///
/// Connect VCC to Pico 3V3(OUT), GND to GND, SDA to GP4, and SCL to GP5.
/// This module has no reset pin; the controller is reset through its init sequence.
///
/// These defaults are a board-wiring transform of the Elegoo OLED documentation,
/// not a new display protocol implementation.
struct PicoSSD1306Configuration {
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
    ///   - sdaPin: An I2C0-capable GPIO used for SDA. The Pico default is GP4.
    ///   - sclPin: The matching I2C0-capable GPIO used for SCL. The Pico default is GP5.
    ///   - i2cClockHz: Bus frequency. The supplied driver supports up to 400 kHz.
    init(
        i2cAddress: UInt8 = 0x3c,
        sdaPin: UInt32 = 4,
        sclPin: UInt32 = 5,
        i2cClockHz: UInt32 = 400_000
    ) {
        self.i2cAddress = i2cAddress
        self.sdaPin = sdaPin
        self.sclPin = sclPin
        self.i2cClockHz = i2cClockHz
    }
}