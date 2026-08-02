/// A sample that demonstrates a variarty of features,
/// including rotary encoder input, traffic light output, and SSD1306 display rendering.
class Sample {
  // MARK: - Pin Assignments -

  private let dtPin: UInt32 = 14
  private let clkPin: UInt32 = 15
  private let ledPin: UInt32 = 25
  private let dht11DataPin: UInt32 = 22
  private let redPin: UInt32 = 2
  private let yellowPin: UInt32 = 3
  private let greenPin: UInt32 = 4
  private let dht11MinimumIntervalMs: UInt32 = 2_000

  // MARK: - Display -

  private var renderer: SSD1306Renderer!
  private var display: SSD1306Driver!

  // MARK: - Sample -

  /// Runs the sample, which demonstrates rotary encoder input, traffic light output, and SSD1306 display rendering.
  func run() -> Never {
    let rotaryButton = RotaryButton(
      configuration: RotaryButtonConfiguration(dtPin: dtPin, clkPin: clkPin)
    )
    rotaryButton.configure()

    // Traffc light wiring
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)
    RP2040GPIO.configureAsSIOOutput(pin: redPin)
    RP2040GPIO.configureAsSIOOutput(pin: yellowPin)
    RP2040GPIO.configureAsSIOOutput(pin: greenPin)

    // Configure display driver
    display = SSD1306Driver(configuration: SSD1306Configuration())
    if case .failure = display.initialize() {
      let alternateAddressDisplay = SSD1306Driver(
        configuration: SSD1306Configuration(i2cAddress: 0x3d)
      )

      guard case .success = alternateAddressDisplay.initialize() else {
        displayFaultLoop(blinks: 4)
      }

      display = alternateAddressDisplay
    }

    // Configure renderer
    renderer = SSD1306Renderer(display: display)

    // Match the reference example: let the controller and charge pump settle.
    pico_delay_ms(2_000)

    let dht11 = DHT11(configuration: DHT11Configuration(dataPin: dht11DataPin))
    dht11.configure()

    display.clear()
    renderer.drawTitle("DHT11")
    _ = display.flush()

    while true {
      showCycleIndicator()

      do {
        let reading = try dht11.read()
        display.clear()
        renderer.drawTitle("DHT11")
        renderer.drawReading(reading)
      } catch {
        display.clear()
        renderer.drawTitle("DHT11")
        renderer.drawReading(nil)

        if case DHT11Error.timeout = error {
          showRed()
        } else {
          showGreen()
        }
      }

      // DHT11 datasheet minimum sampling period is about 1 Hz to 0.5 Hz.
      pico_delay_ms(dht11MinimumIntervalMs)
    }
  }

  // MARK: - Rendering -

  /// Triggeres a new render cycle for the display
  ///
  /// - Parameter activeLight: The light to illuminate.
  private func render(activeLight: TrafficLightColor) {
    display.clear()
    renderer.drawTitle("Hello Swift Embedded")
    renderer.drawTrafficLight(activeLight: activeLight)

    guard case .success = display.flush() else {
      displayFaultLoop(blinks: 2)
    }
  }

  // MARK: - Helper -

  /// Show a brief indicator on the onboard LED to
  /// signal a cycle change.
  private func showCycleIndicator() {
    RP2040GPIO.setHigh(pin: ledPin)
    pico_delay_ms(100)
    RP2040GPIO.setLow(pin: ledPin)
  }

  /// Show the red light on, and turn off yellow and green lights.
  private func showRed() {
    RP2040GPIO.setHigh(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)

    render(activeLight: .red)
  }

  /// Show the yellow light on, and turn off red and green lights.
  private func showYellow() {
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setHigh(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)

    render(activeLight: .yellow)
  }

  /// Show the green light on, and turn off red and yellow lights.
  private func showGreen() {
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setHigh(pin: greenPin)

    render(activeLight: .green)
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
