/// A simple buzzer device that can be controlled via a GPIO pin.
struct Buzzer {

  //MARK: - Pin assignments -

  private let pin: UInt32

  /// Creates a new instance of the Buzzer device with
  /// the specified configuration.
  ///
  /// - Parameter configuration: Configuration object containing the trigger pin for the buzzer.
  init(configuration: BuzzerConfiguration) {
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

/// Configuration object for the Buzzer device.
struct BuzzerConfiguration {
  let triggerPin: UInt32
}
