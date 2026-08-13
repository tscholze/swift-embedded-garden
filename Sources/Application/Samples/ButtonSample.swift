/// Demonstrates button-controlled onboard LED output.
///
/// The LED is on while the button is pressed and off when released.
struct ButtonSample {
  // MARK: - Private properties -

  private let buttonPin: UInt32

  // MARK: - Initialization -

  /// Initializes the sample and configures the button pin.
  /// To run the sample, call the never-returning `run()` method.
  ///
  /// - Parameter buttonPin: The GPIO pin number to which the button is connected.
  init(buttonPin: UInt32 = 16) {
    self.buttonPin = buttonPin
  }

  // MARK: - Sample -

  func run() -> Never {
    RP2040GPIO.configureLed()

    let button = Button(
      configuration: Button.Configuration(triggerPin: buttonPin)
    )

    while true {
      if button.isPressed() {
        RP2040GPIO.setLedHigh()
      } else {
        RP2040GPIO.setLedLow()
      }

      // Small poll delay to avoid busy-looping while keeping responsiveness.
      pico_delay_ms(10)
    }
  }
}
