/// A simple button that can be used to trigger
/// actions in the application.
struct Button {
  // MARK: - Private properties -
  private let configuration: Configuration

  /// Pressed state seen during the previous `wasPressed()` call.
  private var lastPressed: Bool

  // MARK: - Initialization -

  /// Creates a new button for given configuration
  ///
  /// - Parameter configuration: Settings that shall be used
  init(configuration: Configuration) {
    self.configuration = configuration
    self.lastPressed = false
    configure()

    // Adopt the level the pin actually sits at, so a button already held at
    // start-up is not reported as a fresh press.
    self.lastPressed = Self.readPressed(configuration)
  }

  // MARK: - Public methods -

  /// Checks if the button is held down right now.
  func isPressed() -> Bool {
    return Self.readPressed(configuration)
  }

  /// Checks if the button was pressed since
  /// the last time this method was called.
  ///
  /// Returns `true` only on the transition from released to pressed, so
  /// holding the button down does not trigger repeatedly.
  mutating func wasPressed() -> Bool {
    let pressed = Self.readPressed(configuration)
    defer { lastPressed = pressed }
    return pressed && !lastPressed
  }

  // MARK: - Private methods -

  private func configure() {
    let pull: RP2040GPIO.Pull = configuration.isActiveHigh ? .down : .up
    RP2040GPIO.configureAsSIOInput(pin: configuration.triggerPin, pull: pull)
  }

  private static func readPressed(_ configuration: Configuration) -> Bool {
    return RP2040GPIO.read(pin: configuration.triggerPin) == configuration.isActiveHigh
  }
}

// MARK: - Configuration -

extension Button {
  /// A configuration for a button.
  struct Configuration {
    // MARK: - Internal properties -

    /// The GPIO pin that is used to trigger the button.
    let triggerPin: UInt32

    /// Whether a press drives the trigger pin high.
    ///
    /// The KY-004 switches the pin to VCC and carries a pull-down, so it is
    /// active high. A bare switch against GND, or the KY-040's SW pin, is not.
    let isActiveHigh: Bool

    // MARK: - Initialization -

    /// Creates a button configuration.
    ///
    /// - Parameters:
    ///  - triggerPin: The GPIO pin that is used to trigger the button.
    /// - isActiveHigh: Whether a press drives the trigger pin high.
    init(triggerPin: UInt32, isActiveHigh: Bool = true) {
      self.triggerPin = triggerPin
      self.isActiveHigh = isActiveHigh
    }

    // MARK: - Constants -

    /// Default configuration for the button used by the sample.
    static let `default` = Configuration(triggerPin: 13, isActiveHigh: true)
  }
}
