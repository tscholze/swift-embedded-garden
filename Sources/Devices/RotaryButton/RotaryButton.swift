/// High-level wrapper for the rotary button device abstraction.
struct RotaryButton {
  private let controller: RotaryButtonController

  /// Creates a rotary-button wrapper from configuration.
  init(configuration: RotaryButtonConfiguration) {
    self.controller = RotaryButtonController(configuration: configuration)
    controller.configure()
  }

  /// Waits for the next valid direction change.
  func waitForDirection() -> Int? {
    controller.waitForDirection()
  }
}
