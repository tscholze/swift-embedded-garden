struct BuzzerSample {
  private let buzzerPin: UInt32 = 28
  private let ledPin: UInt32 = 25

  init() {
    RP2040GPIO.configureAsSIOOutput(pin: buzzerPin)
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)
  }

  func run() -> Never {
    while true {
      RP2040GPIO.setHigh(pin: buzzerPin)
      RP2040GPIO.setHigh(pin: ledPin)
      pico_delay_ms(2_000)
      RP2040GPIO.setLow(pin: buzzerPin)
      RP2040GPIO.setLow(pin: ledPin)
      pico_delay_ms(2_000)
    }
  }
}
