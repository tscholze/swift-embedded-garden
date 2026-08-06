/// A simple button that can be used to trigger
///  actions in the application.
struct Button {
  // MARK: - Private properties -
  private let configuration: ButtonConfiguration

  // MARK: - Initialization -

  /// Creates a new button for given configuration
  ///
  /// - Parameter configuration: Settings that shall be used
  init(configuration: ButtonConfiguration) {
    self.configuration = configuration
    configure()
  }

  // MARK: - Public methods -

  /// Checks if the button was pressed since
  ///  the last time this method was called.
  func isPressed() -> Bool {
    return !RP2040GPIO.read(pin: configuration.triggerPin)
  }

  // MARK: - Private methods -

  private func configure() {
    RP2040GPIO.configureAsSIOInput(pin: configuration.triggerPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.triggerPin)
  }
}

/// A configuration for a button, which defines
struct ButtonConfiguration {
  /// The GPIO pin that is used to trigger the button.
  let triggerPin: UInt32
}
