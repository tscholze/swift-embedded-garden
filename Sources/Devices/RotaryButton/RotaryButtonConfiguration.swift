extension RotaryButton {
  /// Configuration values for the rotary button / encoder used by the sample.
  struct Configuration {

    // MARK: - Internal properties -

    /// The GPIO connected to the encoder's DT pin.
    let dtPin: UInt32

    /// The GPIO connected to the encoder's CLK pin.
    let clkPin: UInt32

    /// Debounce delay in milliseconds applied before a stable state read.
    let debounceMs: UInt32

    /// Timeout in milliseconds for waiting for the next valid edge.
    let timeoutMs: UInt32

    // MARK: - Initialization -

    /// Creates rotary-button configuration.
    ///
    /// - Parameters:
    ///   - dtPin: The GPIO connected to the encoder's DT pin.
    ///   - clkPin: The GPIO connected to the encoder's CLK pin.
    ///   - debounceMs: Debounce delay in milliseconds applied before a stable state read.
    ///   - timeoutMs: Timeout in milliseconds for waiting for the next valid edge.
    init(
      dtPin: UInt32,
      clkPin: UInt32,
      debounceMs: UInt32 = 2,
      timeoutMs: UInt32 = 10_000
    ) {
      self.dtPin = dtPin
      self.clkPin = clkPin
      self.debounceMs = debounceMs
      self.timeoutMs = timeoutMs
    }

    // MARK: - Constants -

    /// Default configuration for the rotary button / encoder used by the sample.
    static let `default` = Configuration(
      dtPin: 14,
      clkPin: 15,
      timeoutMs: 20
    )
  }
}
