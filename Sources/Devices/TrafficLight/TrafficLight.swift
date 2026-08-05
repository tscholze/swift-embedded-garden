/// A simple traffic light simulation using three GPIO pins for red, yellow, and green lights.
/// Source is based on different input mechanisms, such as a rotary encoder or a simple timed sequence.
struct TrafficLight {
  // MARK: - GPIO Pin Assignments -

  private let ledPin: UInt32
  private let redPin: UInt32
  private let yellowPin: UInt32
  private let greenPin: UInt32

  // MARK: - Initialization -

  init(configuration: TrafficLightConfiguration) {
    self.ledPin = 25
    self.redPin = configuration.redPin
    self.yellowPin = configuration.yellowPin
    self.greenPin = configuration.greenPin

    configure()
  }

  // MARK: - Sample -

  func run() -> Never {
    blinkSequence()
  }

  // MARK: - Traffic Light Simulation -

  private func blinkSequence() -> Never {
    while true {
      showCycleIndicator()

      showRed()
      pico_delay_ms(1000)
      showYellow()
      pico_delay_ms(1000)
      showGreen()
      pico_delay_ms(1000)
    }
  }

  /// Use rotary encoder (KY-040) to change the active traffic light.
  /// Wiring (example):
  /// KY-040 GND -> Pico GND
  /// KY-040 +   -> Pico 3.3V
  /// KY-040 DT  -> Pico GPIO14
  /// KY-040 CLK -> Pico GPIO15
  /// KY-040 MS  -> Pico GPIO13 (optional switch)
  // The encoder is read by waiting for CLK edges and sampling DT to
  // determine direction. The selected light is `position % 3`.
  private func blinkWithKnob() -> Never {
    // Encoder pin assignments (change if you wired differently)
    let dtPin: UInt32 = 14
    let clkPin: UInt32 = 15
    let swPin: UInt32 = 13  // push switch (optional)

    // Configure encoder pins as inputs with pull-ups (typical wiring)
    RP2040GPIO.configureAsSIOInput(pin: dtPin)
    RP2040GPIO.enablePadPullUp(pin: dtPin)
    RP2040GPIO.configureAsSIOInput(pin: clkPin)
    RP2040GPIO.enablePadPullUp(pin: clkPin)
    RP2040GPIO.configureAsSIOInput(pin: swPin)
    RP2040GPIO.enablePadPullUp(pin: swPin)

    // Set initial position to 0
    var position: Int = 0

    // Set initial traffic light state
    showRed()

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

  // MARK: - Helper -

  /// Show a brief indicator on the onboard LED to
  /// signal a cycle change.
  func showCycleIndicator() {
    RP2040GPIO.setHigh(pin: ledPin)
    pico_delay_ms(250)
    RP2040GPIO.setLow(pin: ledPin)
  }

  /// Show the red light on, and turn off yellow and green lights.
  func showRed() {
    RP2040GPIO.setHigh(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)
  }

  /// Show the yellow light on, and turn off red and green lights.
  func showYellow() {
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setHigh(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)
  }

  /// Show the green light on, and turn off red and yellow lights.
  func showGreen() {
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setHigh(pin: greenPin)
  }

  func showAllOff() {
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)
  }

  func showAllOn() {
    RP2040GPIO.setHigh(pin: redPin)
    RP2040GPIO.setHigh(pin: yellowPin)
    RP2040GPIO.setHigh(pin: greenPin)
  }

  // MARK: - Private helpers -

  private func configure() {
    RP2040GPIO.configureAsSIOOutput(pin: redPin)
    RP2040GPIO.configureAsSIOOutput(pin: yellowPin)
    RP2040GPIO.configureAsSIOOutput(pin: greenPin)
  }
}

struct TrafficLightConfiguration {
  let redPin: UInt32
  let yellowPin: UInt32
  let greenPin: UInt32
}
