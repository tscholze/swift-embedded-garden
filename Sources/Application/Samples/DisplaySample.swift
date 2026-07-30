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
        var display = SSD1306Driver()
        if case .failure = display.initialize() {
            let alternateAddressDisplay = SSD1306Driver(
                configuration: PicoSSD1306Configuration(i2cAddress: 0x3d)
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

        // Draw a few shapes to demonstrate the graphics API.
        display.drawRect(x: 4, y: 24, width: 34, height: 28)
        display.fillRect(x: 44, y: 30, width: 24, height: 18)
        display.drawCircle(x: 93, y: 38, radius: 13)
        display.fillCircle(x: 116, y: 51, radius: 8)

        guard case .success = display.flush() else { displayFaultLoop(blinks: 2) }
        while true {}
    }

    /// Signals a display failure on the Pico onboard LED without requiring UART.
    ///
    /// - Parameter blinks: Number of short pulses emitted before each long pause.
    private func displayFaultLoop(blinks: UInt32) -> Never {
        let ledPin: UInt32 = 25
        RP2040GPIO.configureAsSIOOutput(pin: ledPin)
        while true {
            for _ in 0..<blinks {
                RP2040GPIO.setHigh(pin: ledPin)
                pico_delay_ms(120)
                RP2040GPIO.setLow(pin: ledPin)
                pico_delay_ms(180)
            }
            pico_delay_ms(1_000)
        }
    }
}
