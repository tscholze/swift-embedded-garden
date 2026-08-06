/// Demonstrates button-controlled onboard LED output.
///
/// The LED is on while the button is pressed and off when released.
struct ButtonSample {
  private let ledPin: UInt32
  private let buttonPin: UInt32
  private let isActiveHigh: Bool

  init(ledPin: UInt32 = 25, buttonPin: UInt32 = 16, isActiveHigh: Bool = true) {
    self.ledPin = ledPin
    self.buttonPin = buttonPin
    self.isActiveHigh = isActiveHigh
  }

  func run() -> Never {
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)

    var button = Button(
      configuration: ButtonConfiguration(triggerPin: buttonPin, isActiveHigh: isActiveHigh)
    )

    while true {
      if button.isPressed() {
        RP2040GPIO.setHigh(pin: ledPin)
      } else {
        RP2040GPIO.setLow(pin: ledPin)
      }

      // Small poll delay to avoid busy-looping while keeping responsiveness.
      pico_delay_ms(5)
    }
  }
}
