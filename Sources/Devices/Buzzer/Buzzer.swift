/// A simple buzzer device that can be controlled via a GPIO pin.
struct Buzzer {
  //MARK: - Pin assignments -

  private let pin: UInt32

  /// Creates a new instance of the Buzzer device with
  /// the specified configuration.
  ///
  /// - Parameter configuration: Configuration object containing the trigger pin for the buzzer.
  init(configuration: Configuration) {
    self.pin = configuration.triggerPin
    configure()
  }

  // MARK: - Internal helper -

  /// Lets the buzzer buzz for given duration.
  ///
  /// - Parameter durationMs: Buzz duratio. Default value: 500
  func buzz(durationMs: UInt32 = 500) {
    RP2040GPIO.setHigh(pin: pin)
    pico_delay_ms(durationMs)
    RP2040GPIO.setLow(pin: pin)
  }

  // MARK: - Private helper -

  private func configure() {
    RP2040GPIO.configureAsSIOOutput(pin: pin)
  }
}

// MARK: - Configuration -

extension Buzzer {
  /// Default configuration for the buzzer used by the sample.
  struct Configuration {

    // MARK: - Internal properties -

    /// Pin that triggers the buzzer. The buzzer is active when the pin is set to high.
    let triggerPin: UInt32

    // MARK: - Constants -

    /// Default configuration for the buzzer used by the sample.
    static let `default` = Configuration(triggerPin: 12)
  }
}
