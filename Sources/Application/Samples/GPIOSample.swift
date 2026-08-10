// Simple runtime example demonstrating GPIO output, input, and pad pulls.
struct GPIOSample {
  // Use the on-board LED and a sample input pin.
  private let inputPin: UInt32 = 15

  /// Run the example. This function never returns.
  func run() -> Never {
    // Configure LED as output.
    RP2040GPIO.configureLed()

    // Configure input pin as SIO input and enable pull-up.
    RP2040GPIO.configureAsSIOInput(pin: inputPin)
    RP2040GPIO.enablePadPullUp(pin: inputPin)

    while true {
      // Blink LED
      RP2040GPIO.setLedHigh()
      pico_delay_ms(200)
      RP2040GPIO.setLedLow()
      pico_delay_ms(200)

      // Read input pin and show how to use the read helper.
      let isHigh = RP2040GPIO.read(pin: inputPin)

      // If input is low (pressed when using pull-up), flash faster briefly.
      if isHigh {
        RP2040GPIO.setLedHigh()
        pico_delay_ms(50)
        RP2040GPIO.setLedLow()
      }
    }
  }
}
