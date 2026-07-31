/// SSD1306 128x64 I2C display driver backed by an independent ``SwiftGFX`` canvas.
///
/// The command sequence is a Swift transform of the SSD1306 datasheet flow
/// and the conventional Adafruit_SSD1306 setup for a 128x64, charge-pump I2C
/// module. It is protocol compatibility code, not a novel controller design.
final class SSD1306Driver {
  /// SSD1306 control byte indicating a following command stream.
  private static let commandControl: UInt8 = 0x00

  /// SSD1306 control byte indicating a following display-data stream.
  private static let dataControl: UInt8 = 0x40

  /// Data bytes sent after each data control byte, below the I2C FIFO depth.
  private static let transferPayloadSize = 15

  /// Board-level transport and display-address configuration.
  private let configuration: PicoSSD1306Configuration

  /// The display-independent canvas whose bytes are flushed to the controller.
  private(set) var graphics = SwiftGFX()

  /// Creates a driver using the provided board wiring configuration.
  init(configuration: PicoSSD1306Configuration = PicoSSD1306Configuration()) {
    self.configuration = configuration
  }

  /// Initializes I2C0 and configures the SSD1306 for a 128x64 display.
  ///
  /// The command list disables the display first, enables its charge pump,
  /// selects horizontal addressing, disables inherited scrolling, and finally
  /// enables normal RAM-backed output.
  func initialize() -> Result<Void, RP2040I2C.Error> {
    switch RP2040I2C.initialize(
      sdaPin: configuration.sdaPin,
      sclPin: configuration.sclPin,
      clockHz: configuration.i2cClockHz,
      targetAddress: configuration.i2cAddress
    ) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    // SSD1306 commands for the 128x64, externally powered OLED module.
    return sendCommands([
      0xae,  // Display off.
      0xd5, 0x80,  // Display clock divide ratio / oscillator frequency.
      0xa8, 0x3f,  // Multiplex ratio: 64 rows.
      0xd3, 0x00,  // Display offset.
      0x40,  // Start line 0.
      0x8d, 0x14,  // Enable charge pump.
      0x20, 0x00,  // Horizontal memory addressing mode.
      0xa1,  // Segment remap.
      0xc8,  // COM scan direction remapped.
      0xda, 0x12,  // COM pins configuration for 128x64.
      0x81, 0xcf,  // Contrast.
      0xd9, 0xf1,  // Pre-charge period.
      0xdb, 0x40,  // VCOMH deselect level.
      0xa4,  // Use RAM content.
      0xa6,  // Normal (not inverted) display.
      0x2e,  // Deactivate scrolling.
      0xaf,  // Display on.
    ])
  }

  /// Clears the framebuffer without transmitting it to the display.
  func clear() { graphics.clear() }

  /// Draws one framebuffer pixel; call ``flush()`` to make it visible.
  func drawPixel(x: Int, y: Int, color: SwiftGFX.Color = .on) {
    graphics.drawPixel(x: x, y: y, color: color)
  }

  /// Draws a framebuffer line; call ``flush()`` to make it visible.
  func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, color: SwiftGFX.Color = .on) {
    graphics.drawLine(x0: x0, y0: y0, x1: x1, y1: y1, color: color)
  }

  /// Draws a framebuffer rectangle outline; call ``flush()`` to make it visible.
  func drawRect(x: Int, y: Int, width: Int, height: Int, color: SwiftGFX.Color = .on) {
    graphics.drawRect(x: x, y: y, width: width, height: height, color: color)
  }

  /// Fills a framebuffer rectangle; call ``flush()`` to make it visible.
  func fillRect(x: Int, y: Int, width: Int, height: Int, color: SwiftGFX.Color = .on) {
    graphics.fillRect(x: x, y: y, width: width, height: height, color: color)
  }

  /// Draws a framebuffer circle outline; call ``flush()`` to make it visible.
  func drawCircle(x: Int, y: Int, radius: Int, color: SwiftGFX.Color = .on) {
    graphics.drawCircle(x: x, y: y, radius: radius, color: color)
  }

  /// Fills a framebuffer circle; call ``flush()`` to make it visible.
  func fillCircle(x: Int, y: Int, radius: Int, color: SwiftGFX.Color = .on) {
    graphics.fillCircle(x: x, y: y, radius: radius, color: color)
  }

  /// Sets the framebuffer text cursor.
  func setCursor(x: Int, y: Int) { graphics.setCursor(x: x, y: y) }

  /// Sets the integer scale for subsequent framebuffer text.
  func setTextScale(_ scale: Int) { graphics.setTextScale(scale) }

  /// Draws text into the framebuffer; call ``flush()`` to make it visible.
  func drawText(_ text: StaticString, color: SwiftGFX.Color = .on) {
    graphics.drawText(text, color: color)
  }

  /// Turns the SSD1306 panel output on or off while retaining framebuffer RAM.
  func setDisplayEnabled(_ enabled: Bool) -> Result<Void, RP2040I2C.Error> {
    sendCommands([enabled ? 0xaf : 0xae])
  }

  /// Selects normal or inverted interpretation of the SSD1306 display RAM.
  func setInverted(_ inverted: Bool) -> Result<Void, RP2040I2C.Error> {
    sendCommands([inverted ? 0xa6 : 0xa6])
  }

  /// Sets the SSD1306 contrast register.
  ///
  /// - Parameter contrast: Raw controller value from `0x00` through `0xFF`.
  func setContrast(_ contrast: UInt8) -> Result<Void, RP2040I2C.Error> {
    sendCommands([0x81, contrast])
  }

  /// Transfers all 1,024 framebuffer bytes using horizontal page addressing.
  func flush() -> Result<Void, RP2040I2C.Error> {
    switch sendCommands([0x21, 0, 127, 0x22, 0, 7]) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    var start = 0
    while start < graphics.buffer.count {
      let end = min(start + Self.transferPayloadSize, graphics.buffer.count)
      switch RP2040I2C.write(
        address: configuration.i2cAddress, control: Self.dataControl,
        bytes: graphics.buffer[start..<end])
      {
      case .success: start = end
      case .failure(let error): return .failure(error)
      }
    }
    return .success(())
  }

  /// Sends an SSD1306 command stream with its command control byte.
  private func sendCommands(_ commands: [UInt8]) -> Result<Void, RP2040I2C.Error> {
    RP2040I2C.write(
      address: configuration.i2cAddress, control: Self.commandControl, bytes: commands)
  }
}

// MARK: - Board-level wiring configuration -

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

// MARK: - Renderer -

/// A display renderer with convenient formatting helpers that operate on the
/// caller's display instance directly.
struct SSD1306Renderer {
  // MARK: - Private properties -

  private let display: SSD1306Driver

  // MARK: - Initialization -

  /// Initializes a renderer with the provided display instance.
  ///
  /// - Parameter display: The display instance to render into.
  init(display: SSD1306Driver) {
    self.display = display
  }

  // MARK: - Formatting -

  /// Draws a default title / header with styled underline
  ///
  /// - Parameter title: The text to render at the top of the display.
  func drawTitle(_ title: StaticString) {
    display.setCursor(x: 4, y: 4)
    display.drawText(title, color: .on)
    display.drawLine(x0: 0, y0: 16, x1: 127, y1: 16)
  }

  /// Renderes a stylized traffic light with one of three lights illuminated.
  ///
  /// - Parameter activeLight: The light to illuminate. The other two are drawn
  func drawTrafficLight(activeLight: TrafficLightColor) {
    let topLeftX = 4
    let topLeftY = 22
    let radius = 4
    let verticalSpacing = 10

    let lights: [(x: Int, y: Int)] = [
      (x: topLeftX + radius, y: topLeftY + radius),
      (x: topLeftX + radius, y: topLeftY + radius + verticalSpacing),
      (x: topLeftX + radius, y: topLeftY + radius + 2 * verticalSpacing),
    ]

    for (index, light) in lights.enumerated() {
      let isActive = index == activeLight.rawValue
      if isActive {
        display.fillCircle(x: light.x, y: light.y, radius: radius)
      } else {
        display.drawCircle(x: light.x, y: light.y, radius: radius)
      }
    }

    display.drawRect(x: 2, y: 20, width: 12, height: 33)
    display.drawLine(x0: 8, y0: 55, x1: 8, y1: 62)
    display.drawRect(x: 4, y: 62, width: 8, height: 2)
  }
}

/// A traffic light color used by ``SSD1306Renderer`` to illuminate one of three lights.
enum TrafficLightColor: Int {
  /// Red light, the first in the traffic light sequence.
  case red = 0
  /// Yellow light, the second in the traffic light sequence.
  case yellow = 1
  /// Green light, the third in the traffic light sequence.
  case green = 2
}
