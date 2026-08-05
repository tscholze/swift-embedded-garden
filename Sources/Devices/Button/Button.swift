struct Button {

  private let configuration: ButtonConfiguration

  init(configuration: ButtonConfiguration) {
    self.configuration = configuration
    configure()
  }

  private func configure() {
    RP2040GPIO.configureAsSIOInput(pin: configuration.triggerPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.triggerPin)
  }

  func isPressed() -> Bool {
    return !RP2040GPIO.read(pin: configuration.triggerPin)
  }
}

struct ButtonConfiguration {
  let triggerPin: UInt32
}
