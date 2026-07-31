/// A sample that demonstrates a variarty of features,
/// including rotary encoder input, traffic light output, and SSD1306 display rendering.
class Sample {
  // MARK: - Pin Assignments -

  private let dtPin: UInt32 = 14
  private let clkPin: UInt32 = 15
  private let ledPin: UInt32 = 25
  private let redPin: UInt32 = 2
  private let yellowPin: UInt32 = 3
  private let greenPin: UInt32 = 4

  // MARK: - Display -

  private var renderer: SSD1306Renderer!
  private var display: SSD1306Driver!

  // MARK: - Sample -

  /// Runs the sample
  func run() -> Never {
    // Display wiring
    RP2040GPIO.configureAsSIOInput(pin: dtPin)
    RP2040GPIO.enablePadPullUp(pin: dtPin)
    RP2040GPIO.configureAsSIOInput(pin: clkPin)
    RP2040GPIO.enablePadPullUp(pin: clkPin)

    // Traffc light wiring
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)
    RP2040GPIO.configureAsSIOOutput(pin: redPin)
    RP2040GPIO.configureAsSIOOutput(pin: yellowPin)
    RP2040GPIO.configureAsSIOOutput(pin: greenPin)

    // Configure display driver
    display = SSD1306Driver()
    if case .failure = display.initialize() {
      let alternateAddressDisplay = SSD1306Driver(
        configuration: PicoSSD1306Configuration(i2cAddress: 0x3d)
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

    // Draw the initial frame and send it to the display.
    render(activeLight: .red)

    var position = 0

    while true {
      showCycleIndicator()

      // Wait for rising edge on CLK (blocks).
      _ = RP2040GPIO.waitForRisingEdge(pin: clkPin, timeoutMs: 10_000)

      // read DT to determine direction; typical rule: when CLK rises,
      // if DT!=CLK then direction is one way, otherwise the other.
      let dtHigh = RP2040GPIO.read(pin: dtPin)
      let clkHigh = RP2040GPIO.read(pin: clkPin)

      if dtHigh != clkHigh {
        position += 1
      } else {
        position -= 1
      }

      // apply modulo 3 mapping: 0 -> red, 1 -> yellow, 2 -> green
      let modulo = ((position % 3) + 3) % 3
      switch modulo {
      case 0: showRed()
      case 1: showYellow()
      case 2: showGreen()
      default: showRed()
      }

      // small debounce delay
      pico_delay_ms(250)
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
