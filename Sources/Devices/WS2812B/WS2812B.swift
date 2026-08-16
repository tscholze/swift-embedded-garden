/// WS2812B is a type that represents a WS2812B LED strip. It provides functionality to control the individual pixels of the strip,
/// allowing for the creation of various lighting effects and animations.
///
/// The WS2812B is a popular addressable RGB LED that can be controlled using a single data line,
/// making it ideal for creating colorful displays in embedded systems.
///
/// It is also known as "Neopixel".
///
/// Roughly based on:
///     - https://github.com/swiftlang/swift-embedded-examples/tree/main/stm32-neopixel/Sources/Application/Neopixel
struct WS2812B {

  let configuration: Configuration

  // MARK: - Internal properties -

  /// Set pixels attributes (color) at (x,y) position.
  ///
  /// - Parameters:
  ///   - x: The x-coordinate of the pixel.
  ///   - y: The y-coordinate of the pixel.
  ///   - r: The red component of the pixel color (0-255).
  ///   - g: The green component of the pixel color (0-255).
  ///   - b: The blue component of the pixel color (0-255).
  func setPixel(x: Int, y: Int, r: UInt8, g: UInt8, b: UInt8) {
    fatalError("Not implemented yet")
  }

  /// Bulk update of all pixels attributes (color).
  /// Required after each setPixel() to update the LED strip.
  func show() {
    fatalError("Not implemented yet")
  }

  /// Clear all pixels (set to black/off).
  func clear() {
    fatalError("Not implemented yet")
  }

  // MARK: - Private helper -

  /// Converts (x,y) to LED index considering serpentine wiring.
  ///
  /// - Parameters:
  ///   - x: The x-coordinate of the pixel.
  ///   - y: The y-coordinate of the pixel.
  /// - Returns: The index of the pixel in the LED strip.
  private func index(x: Int, y: Int) -> Int {
    if y % 2 == 0 {
      return y * configuration.numberOfPixelsX + x
    } else {
      return y * configuration.numberOfPixelsX + (configuration.numberOfPixelsX - 1 - x)
    }
  }
}
