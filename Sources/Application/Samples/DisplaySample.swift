/// Demonstrates the Elegoo SSD1306 display on I2C0 (GP4 SDA, GP5 SCL).
///
/// The rendering flow is a Swift transform of the familiar Arduino example:
/// initialize, wait for the charge pump, draw into a framebuffer, then flush.
/// The Arduino sample provided the behavioral reference; this file does not
/// include Arduino library code.
struct DisplaySample {
  /// Initializes the display, renders the static demonstration, then idles.
  ///
  /// The sample attempts `0x3C` first and retries at `0x3D`, covering the
  /// two common addresses used by otherwise compatible SSD1306 modules.
  /// A one-blink LED fault means initialization failed; two blinks means the
  /// display accepted initialization but rejected the framebuffer transfer.
  func run() -> Never {
    var display = SSD1306(configuration: SSD1306.Configuration())
    if case .failure = display.initialize() {
      let alternateAddressDisplay = SSD1306(
        configuration: SSD1306.Configuration(i2cAddress: 0x3d)
      )

      guard case .success = alternateAddressDisplay.initialize() else {
        displayFaultLoop(blinks: 1)
      }

      display = alternateAddressDisplay
    }

    let renderer = SSD1306Renderer(display: display)

    // Match the reference example: let the controller and charge pump settle.
    pico_delay_ms(2_000)

    // Clear display / framebuffer
    display.clear()

    // Draw a title / header
    renderer.drawTitle("Hello Swift Embedded")

    renderer.drawTrafficLight(activeLight: .green)

    guard case .success = display.flush() else { displayFaultLoop(blinks: 2) }
    while true {}
  }

  /// Signals a display failure on the Pico onboard LED without requiring UART.
  ///
  /// - Parameter blinks: Number of short pulses emitted before each long pause.
  private func displayFaultLoop(blinks: UInt32) -> Never {

    RP2040GPIO.configureLed()
    while true {
      for _ in 0..<blinks {
        RP2040GPIO.setLedHigh()
        pico_delay_ms(120)
        RP2040GPIO.setLedLow()
        pico_delay_ms(180)
      }
      pico_delay_ms(1_000)
    }
  }
}
