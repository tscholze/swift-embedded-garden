/// A simple traffic light simulation using three GPIO pins for red, yellow, and green lights.
/// Source is based on different input mechanisms, such as a rotary encoder or a simple timed sequence.
struct TrafficLightSample {
  // MARK: - GPIO Pin Assignments -

  private let trafficLight: TrafficLight

  // MARK: - Initialization -

  /// Initializes the sample and configures the traffic light pins.
  /// To run the sample, call the never-returning `run()` method.
  ///
  /// - Parameter configuration: The configuration for the traffic light.
  init(configuration: TrafficLight.Configuration) {
    trafficLight = TrafficLight(configuration: configuration)
  }

  // MARK: - Sample run -

  func run() -> Never {
    // 1. Simple blink
    blinkSequence()

    // 2. Rotary encoder input
    // blinkWithKnob()
  }

  // MARK: - Traffic Light Simulation -

  private func blinkSequence() -> Never {
    while true {
      trafficLight.showCycleIndicator()

      trafficLight.showRed()
      pico_delay_ms(1000)
      trafficLight.showYellow()
      pico_delay_ms(1000)
      trafficLight.showGreen()
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
    trafficLight.showRed()

    while true {
      trafficLight.showCycleIndicator()

      // Wait for rising edge on CLK (blocks).
      _ = RP2040GPIO.waitForRisingEdge(pin: clkPin, timeoutUs: 10_000 * 1_000)

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
      case 0: trafficLight.showRed()
      case 1: trafficLight.showYellow()
      case 2: trafficLight.showGreen()
      default: trafficLight.showRed()
      }

      // small debounce delay
      pico_delay_ms(250)
    }
  }
}
