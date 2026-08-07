/// High-level wrapper for the rotary button device abstraction.
struct RotaryButton {
  private let configuration: RotaryButtonConfiguration

  /// Creates a controller for the supplied rotary-button configuration.
  init(configuration: RotaryButtonConfiguration) {
    self.configuration = configuration
    configure()
  }

  /// Configures the DT and CLK pins as input pins with pull-ups enabled.
  func configure() {
    RP2040GPIO.configureAsSIOInput(pin: configuration.dtPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.dtPin)
    RP2040GPIO.configureAsSIOInput(pin: configuration.clkPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.clkPin)
  }

  /// Waits for the next valid encoder movement and returns the movement direction.
  ///
  /// - Returns: `1` for a clockwise step, `-1` for a counter-clockwise step, or `nil` if the state was unstable or the timeout elapsed.
  func waitForDirection() -> Int? {
    guard
      RP2040GPIO.waitForRisingEdge(
        pin: configuration.clkPin, timeoutUs: configuration.timeoutMs * 1_000)
    else {
      return nil
    }

    guard let state = readStableEncoderState() else {
      pico_delay_ms(50)
      return nil
    }

    return state.dt != state.clk ? 1 : -1
  }

  /// Reads the encoder inputs twice with a short delay to filter out bounce.
  private func readStableEncoderState() -> (dt: Bool, clk: Bool)? {
    let first = (
      RP2040GPIO.read(pin: configuration.dtPin), RP2040GPIO.read(pin: configuration.clkPin)
    )
    pico_delay_ms(configuration.debounceMs)
    let second = (
      RP2040GPIO.read(pin: configuration.dtPin), RP2040GPIO.read(pin: configuration.clkPin)
    )

    return first == second ? (dt: first.0, clk: first.1) : nil
  }
}
