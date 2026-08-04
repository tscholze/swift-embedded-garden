// PWM demo: Ramp LED brightness using RP2040PWM helpers.

struct PWMSample {
  private let ledPin: UInt32 = 25

  func run() -> Never {
    // Configure PWM on LED pin at 1000 Hz, initial 0% duty.
    switch RP2040PWM.configure(pin: ledPin, frequencyHz: 1000, dutyPercent: 0.0) {
    case .success:
      break
    case .failure(let err):
      // If configuration failed, fall back to simple blink
      _ = err
      // Configure as simple SIO output and blink
      RP2040GPIO.configureAsSIOOutput(pin: ledPin)
      while true {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(200)
        RP2040GPIO.setLow(pin: ledPin)
        pico_delay_ms(200)
      }
    }

    // Ramp brightness up and down
    while true {
      for i in 0...100 {
        RP2040PWM.setDuty(pin: ledPin, dutyPercent: Double(i))
        pico_delay_ms(10)
      }
      for i in (0...100).reversed() {
        RP2040PWM.setDuty(pin: ledPin, dutyPercent: Double(i))
        pico_delay_ms(10)
      }
    }
  }
}
