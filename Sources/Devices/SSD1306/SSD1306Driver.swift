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
  private let configuration: SSD1306Configuration

  /// The display-independent canvas whose bytes are flushed to the controller.
  private(set) var graphics = SwiftGFX()

  /// Creates a driver using the provided board wiring configuration.
  init(configuration: SSD1306Configuration = SSD1306Configuration()) {
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

  /// Draws runtime text into the framebuffer; call ``flush()`` to make it visible.
  func drawText(_ text: String, color: SwiftGFX.Color = .on) {
    graphics.drawText(text, color: color)
  }

  /// Turns the SSD1306 panel output on or off while retaining framebuffer RAM.
  func setDisplayEnabled(_ enabled: Bool) -> Result<Void, RP2040I2C.Error> {
    sendCommands([enabled ? 0xaf : 0xae])
  }

  /// Selects normal or inverted interpretation of the SSD1306 display RAM.
  func setInverted(_ inverted: Bool) -> Result<Void, RP2040I2C.Error> {
    sendCommands([inverted ? 0xa7 : 0xa6])
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
