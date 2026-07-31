// Simple runtime example demonstrating GPIO output, input, and pad pulls.
struct GPIOExample {
  // Use the on-board LED and a sample input pin.
  private let ledPin: UInt32 = 25
  private let inputPin: UInt32 = 15

  /// Run the example. This function never returns.
  func run() -> Never {
    // Configure LED as output.
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)

    // Configure input pin as SIO input and enable pull-up.
    RP2040GPIO.configureAsSIOInput(pin: inputPin)
    RP2040GPIO.enablePadPullUp(pin: inputPin)

    while true {
      // Blink LED
      RP2040GPIO.setHigh(pin: ledPin)
      pico_delay_ms(200)
      RP2040GPIO.setLow(pin: ledPin)
      pico_delay_ms(200)

      // Read input pin and show how to use the read helper.
      let pressed = RP2040GPIO.read(pin: inputPin)

      // If input is low (pressed when using pull-up), flash faster briefly.
      if !pressed {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(50)
        RP2040GPIO.setLow(pin: ledPin)
      }
    }
  }
}
