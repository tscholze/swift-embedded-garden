extension WS2812B {
  /// Configuration is a struct that holds the configuration parameters for a WS2812B LED strip.
  struct Configuration {
    // MARK: - Internal properties -

    /// The number of pixels in the X direction (width) of the LED strip.
    let numberOfPixelsX: Int

    /// The number of pixels in the Y direction (height) of the LED strip.
    let numberOfPixelsY: Int

    // MARK: - Default -

    /// A default configuration for a WS2812B LED strip with 8 pixels in
    /// the X direction and 8 pixels in the Y direction.
    static let `default` = Configuration(numberOfPixelsX: 8, numberOfPixelsY: 8)
  }
}
