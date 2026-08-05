struct Buzzer {
  private let pin: UInt32

  init(configuration: BuzzerConfiguration) {
    self.pin = configuration.triggerPin
    configure()
  }

  private func configure() {
    RP2040GPIO.configureAsSIOOutput(pin: pin)
  }

  func buzz(durationMs: UInt32 = 2_000) {
    RP2040GPIO.setHigh(pin: pin)
    pico_delay_ms(durationMs)
    RP2040GPIO.setLow(pin: pin)
  }
}

struct BuzzerConfiguration {
  let triggerPin: UInt32
}
