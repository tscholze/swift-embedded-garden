/// A compact, display-independent 1-bit graphics canvas for 128x64 displays.
///
/// Pixels use SSD1306-compatible page storage: a byte stores eight vertical
/// pixels at one x-coordinate. The canvas has no I2C or controller dependency,
/// allowing a future display driver to consume the same framebuffer.
///
/// The line and circle routines are standard Bresenham and midpoint raster
/// algorithms. The compact glyph data follows the classic 5x7, column-major
/// ASCII format used by Adafruit_GFX's bundled font. This is a compatible
/// format-level transform for embedded use, not an original typeface design.
struct SwiftGFX {
  /// Describes how a drawing operation changes a framebuffer pixel.
  enum Color {
    /// Clears the selected pixels.
    case off

    /// Sets the selected pixels.
    case on

    /// Toggles the selected pixels.
    case invert
  }

  /// The fixed framebuffer width, in pixels.
  static let width = 128

  /// The fixed framebuffer height, in pixels.
  static let height = 64

  /// The number of bytes required by the 128x64 one-bit framebuffer.
  static let bufferSize = width * height / 8

  /// Page-addressed framebuffer bytes in SSD1306 transmission order.
  private(set) var buffer = [UInt8](repeating: 0, count: bufferSize)

  /// Horizontal position used by the next text glyph.
  private var cursorX = 0

  /// Vertical position used by the next text glyph.
  private var cursorY = 0

  /// Positive integer multiplier applied to each text glyph pixel.
  private var textScale = 1

  /// Fills the entire framebuffer with one color.
  ///
  /// - Parameter color: `.off` clears the display; `.on` sets every pixel.
  ///   `.invert` is treated as `.off` because a uniform inverse fill has no
  ///   unambiguous prior pixel state.
  mutating func clear(_ color: Color = .off) {
    let fill: UInt8 = color == .on ? 0xff : 0
    for index in buffer.indices { buffer[index] = fill }
  }

  /// Draws one bounds-checked pixel into the framebuffer.
  ///
  /// - Parameters:
  ///   - x: Horizontal coordinate, from `0` through `127`.
  ///   - y: Vertical coordinate, from `0` through `63`.
  ///   - color: Pixel operation to apply. Out-of-bounds coordinates are ignored.
  mutating func drawPixel(x: Int, y: Int, color: Color = .on) {
    guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return }
    let index = x + (y >> 3) * Self.width
    let mask = UInt8(1 << (y & 7))
    switch color {
    case .off: buffer[index] &= ~mask
    case .on: buffer[index] |= mask
    case .invert: buffer[index] ^= mask
    }
  }

  /// Draws a line using the integer Bresenham rasterization algorithm.
  ///
  /// - Parameters:
  ///   - x0: Horizontal coordinate of the first endpoint.
  ///   - y0: Vertical coordinate of the first endpoint.
  ///   - x1: Horizontal coordinate of the second endpoint.
  ///   - y1: Vertical coordinate of the second endpoint.
  ///   - color: Pixel operation applied along the line.
  mutating func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, color: Color = .on) {
    var currentX = x0
    var currentY = y0
    let deltaX = abs(x1 - x0)
    let stepX = x0 < x1 ? 1 : -1
    let deltaY = -abs(y1 - y0)
    let stepY = y0 < y1 ? 1 : -1
    var error = deltaX + deltaY

    while true {
      drawPixel(x: currentX, y: currentY, color: color)
      if currentX == x1 && currentY == y1 { return }
      let twiceError = error * 2
      if twiceError >= deltaY {
        error += deltaY
        currentX += stepX
      }
      if twiceError <= deltaX {
        error += deltaX
        currentY += stepY
      }
    }
  }

  /// Draws the outline of an axis-aligned rectangle.
  ///
  /// Non-positive dimensions are ignored; portions outside the framebuffer
  /// are clipped by ``drawPixel(x:y:color:)``.
  mutating func drawRect(x: Int, y: Int, width: Int, height: Int, color: Color = .on) {
    guard width > 0, height > 0 else { return }
    drawLine(x0: x, y0: y, x1: x + width - 1, y1: y, color: color)
    drawLine(x0: x, y0: y + height - 1, x1: x + width - 1, y1: y + height - 1, color: color)
    drawLine(x0: x, y0: y, x1: x, y1: y + height - 1, color: color)
    drawLine(x0: x + width - 1, y0: y, x1: x + width - 1, y1: y + height - 1, color: color)
  }

  /// Fills an axis-aligned rectangle with horizontal lines.
  ///
  /// Non-positive dimensions are ignored; portions outside the framebuffer
  /// are clipped by ``drawPixel(x:y:color:)``.
  mutating func fillRect(x: Int, y: Int, width: Int, height: Int, color: Color = .on) {
    guard width > 0, height > 0 else { return }
    for row in 0..<height {
      drawLine(x0: x, y0: y + row, x1: x + width - 1, y1: y + row, color: color)
    }
  }

  /// Draws a circle outline using the integer midpoint circle algorithm.
  ///
  /// - Parameters:
  ///   - x: Horizontal coordinate of the circle center.
  ///   - y: Vertical coordinate of the circle center.
  ///   - radius: Radius in pixels. Negative values are ignored.
  ///   - color: Pixel operation applied to the circumference.
  mutating func drawCircle(x: Int, y: Int, radius: Int, color: Color = .on) {
    guard radius >= 0 else { return }
    var offsetX = radius
    var offsetY = 0
    var error = 1 - radius
    while offsetX >= offsetY {
      drawPixel(x: x + offsetX, y: y + offsetY, color: color)
      drawPixel(x: x + offsetY, y: y + offsetX, color: color)
      drawPixel(x: x - offsetY, y: y + offsetX, color: color)
      drawPixel(x: x - offsetX, y: y + offsetY, color: color)
      drawPixel(x: x - offsetX, y: y - offsetY, color: color)
      drawPixel(x: x - offsetY, y: y - offsetX, color: color)
      drawPixel(x: x + offsetY, y: y - offsetX, color: color)
      drawPixel(x: x + offsetX, y: y - offsetY, color: color)
      offsetY += 1
      if error < 0 {
        error += 2 * offsetY + 1
      } else {
        offsetX -= 1
        error += 2 * (offsetY - offsetX) + 1
      }
    }
  }

  /// Fills a circle with horizontal spans.
  ///
  /// - Parameters:
  ///   - x: Horizontal coordinate of the circle center.
  ///   - y: Vertical coordinate of the circle center.
  ///   - radius: Radius in pixels. Negative values are ignored.
  ///   - color: Pixel operation applied to every covered pixel.
  mutating func fillCircle(x: Int, y: Int, radius: Int, color: Color = .on) {
    guard radius >= 0 else { return }
    for offsetY in -radius...radius {
      let squared = radius * radius - offsetY * offsetY
      var offsetX = 0
      while (offsetX + 1) * (offsetX + 1) <= squared { offsetX += 1 }
      drawLine(x0: x - offsetX, y0: y + offsetY, x1: x + offsetX, y1: y + offsetY, color: color)
    }
  }

  /// Sets the top-left coordinate for the next text glyph.
  mutating func setCursor(x: Int, y: Int) {
    cursorX = x
    cursorY = y
  }

  /// Sets the integer scale used by subsequent text rendering.
  ///
  /// Values less than one use one.
  mutating func setTextScale(_ scale: Int) { textScale = max(scale, 1) }

  /// Renders an ASCII-compatible string literal at the current cursor position.
  ///
  /// UTF-8 bytes outside the minimal glyph table render as a fallback glyph.
  /// A line-feed moves the cursor to x-coordinate zero and advances one glyph row.
  mutating func drawText(_ text: StaticString, color: Color = .on) {
    let bytes = text.utf8Start
    let count = text.utf8CodeUnitCount
    for i in 0..<count {
      let character = bytes[i]
      if character == 10 {
        cursorX = 0
        cursorY += 8 * textScale
      } else {
        drawCharacter(character, x: cursorX, y: cursorY, color: color)
        cursorX += 6 * textScale
      }
    }
  }

  /// Renders one 5x7 glyph from the compact column-major font table.
  private mutating func drawCharacter(_ character: UInt8, x: Int, y: Int, color: Color) {
    let columns = glyphColumns(for: character)
    for column in 0..<5 {
      for row in 0..<7 where (columns[column] & UInt8(1 << row)) != 0 {
        fillRect(
          x: x + column * textScale, y: y + row * textScale, width: textScale, height: textScale,
          color: color)
      }
    }
  }

  /// Returns five column bytes for an ASCII glyph or the fallback glyph.
  private func glyphColumns(for character: UInt8) -> [UInt8] {
    let uppercase = character >= 97 && character <= 122 ? character - 32 : character
    switch uppercase {
    case 32: return [0, 0, 0, 0, 0]
    case 33: return [0, 0, 95, 0, 0]
    case 45: return [8, 8, 8, 8, 8]
    case 46: return [0, 96, 96, 0, 0]
    case 48: return [62, 81, 73, 69, 62]
    case 49: return [0, 66, 127, 64, 0]
    case 50: return [66, 97, 81, 73, 70]
    case 51: return [33, 65, 69, 75, 49]
    case 52: return [24, 20, 18, 127, 16]
    case 53: return [39, 69, 69, 69, 57]
    case 54: return [60, 74, 73, 73, 48]
    case 55: return [1, 113, 9, 5, 3]
    case 56: return [54, 73, 73, 73, 54]
    case 57: return [6, 73, 73, 41, 30]
    case 65: return [126, 17, 17, 17, 126]
    case 66: return [127, 73, 73, 73, 54]
    case 67: return [62, 65, 65, 65, 34]
    case 68: return [127, 65, 65, 34, 28]
    case 69: return [127, 73, 73, 73, 65]
    case 70: return [127, 9, 9, 9, 1]
    case 71: return [62, 65, 73, 73, 122]
    case 72: return [127, 8, 8, 8, 127]
    case 73: return [0, 65, 127, 65, 0]
    case 74: return [32, 64, 65, 63, 1]
    case 75: return [127, 8, 20, 34, 65]
    case 76: return [127, 64, 64, 64, 64]
    case 77: return [127, 2, 12, 2, 127]
    case 78: return [127, 4, 8, 16, 127]
    case 79: return [62, 65, 65, 65, 62]
    case 80: return [127, 9, 9, 9, 6]
    case 81: return [62, 65, 81, 33, 94]
    case 82: return [127, 9, 25, 41, 70]
    case 83: return [70, 73, 73, 73, 49]
    case 84: return [1, 1, 127, 1, 1]
    case 85: return [63, 64, 64, 64, 63]
    case 86: return [31, 32, 64, 32, 31]
    case 87: return [127, 32, 24, 32, 127]
    case 88: return [99, 20, 8, 20, 99]
    case 89: return [3, 4, 120, 4, 3]
    case 90: return [97, 81, 73, 69, 67]
    default: return [2, 1, 89, 9, 6]
    }
  }
}
