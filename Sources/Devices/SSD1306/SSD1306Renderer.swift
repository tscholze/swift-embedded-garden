/// A display renderer with convenient formatting helpers that operate on the
/// caller's display instance directly.
struct SSD1306Renderer {
  private let display: SSD1306Driver

  /// Initializes a renderer with the provided display instance.
  ///
  /// - Parameter display: The display instance to render into.
  init(display: SSD1306Driver) {
    self.display = display
  }

  /// Draws a default title / header with styled underline.
  ///
  /// - Parameter title: The text to render at the top of the display.
  func drawTitle(_ title: StaticString) {
    display.setCursor(x: 4, y: 4)
    display.drawText(title, color: .on)
    display.drawLine(x0: 0, y0: 16, x1: 127, y1: 16)
  }

  /// Renders a stylized traffic light with one of three lights illuminated.
  ///
  /// - Parameter activeLight: The light to illuminate. The other two are drawn.
  func drawTrafficLight(activeLight: TrafficLightColor) {
    let topLeftX = 4
    let topLeftY = 22
    let radius = 4
    let verticalSpacing = 10

    let lights: [(x: Int, y: Int)] = [
      (x: topLeftX + radius, y: topLeftY + radius),
      (x: topLeftX + radius, y: topLeftY + radius + verticalSpacing),
      (x: topLeftX + radius, y: topLeftY + radius + 2 * verticalSpacing),
    ]

    for (index, light) in lights.enumerated() {
      let isActive = index == activeLight.rawValue
      if isActive {
        display.fillCircle(x: light.x, y: light.y, radius: radius, color: .invert)
      } else {
        display.drawCircle(x: light.x, y: light.y, radius: radius)
      }
    }

    display.drawRect(x: 2, y: 20, width: 12, height: 33)
    display.drawLine(x0: 8, y0: 55, x1: 8, y1: 62)
    display.drawRect(x: 4, y: 62, width: 8, height: 2)
  }

  /// Draws the latest DHT11 sensor reading into the current framebuffer.
  ///
  /// - Parameters:
  ///   - reading: The sensor sample to render, if available.
  ///   - shiftX: Horizontal shift for the rendering position.
  ///   - shiftY: Vertical shift for the rendering position.
  func drawReading(_ reading: DHT11Reading?, shiftX: Int = 0, shiftY: Int = 0) {
    display.setCursor(x: 4 + shiftX, y: 24 + shiftY)

    if let reading {
      display.drawText("Temperature - ", color: .on)
      display.drawNumber(Int(reading.temperatureC), suffix: "C")
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("Humidity    - ", color: .on)
      display.drawNumber(Int(reading.humidityPercent), suffix: "P")
    } else {
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("No reading", color: .on)
    }

    // _ = display.flush()
  }

  /// Draws the latest DHT11 sensor reading in a shorten representation
  /// into the current framebuffer.
  ///
  /// - Parameters:
  ///   - reading: The sensor sample to render, if available.
  ///   - shiftX: Horizontal shift for the rendering position.
  ///   - shiftY: Vertical shift for the rendering position.
  func drawReadingShort(_ reading: DHT11Reading?, shiftX: Int = 0, shiftY: Int = 0) {
    display.setCursor(x: 4 + shiftX, y: 24 + shiftY)

    if let reading {
      display.drawText("T - ", color: .on)
      display.drawNumber(Int(reading.temperatureC), suffix: "C")
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("H - ", color: .on)
      display.drawNumber(Int(reading.humidityPercent), suffix: "P")
    } else {
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("NA", color: .on)
    }
  }
}

/// A traffic light color used by ``SSD1306Renderer`` to illuminate one of three lights.
enum TrafficLightColor: Int {
  /// Red light, the first in the traffic light sequence.
  case red = 0
  /// Yellow light, the second in the traffic light sequence.
  case yellow = 1
  /// Green light, the third in the traffic light sequence.
  case green = 2
  /// No light illuminated, the fourth in the traffic light sequence.
  case off = 3
}

extension SSD1306Driver {
  fileprivate func drawNumber(
    _ value: Int, suffix: StaticString? = nil, color: SwiftGFX.Color = .on
  ) {
    if value == 0 {
      drawDigit(0, color: color)
    } else {
      if value < 0 {
        drawText("-", color: color)
      }

      var divisor = 1
      var remaining = value < 0 ? -value : value
      while remaining / divisor >= 10 {
        divisor *= 10
      }

      while divisor > 0 {
        let digit = (remaining / divisor) % 10
        drawDigit(digit, color: color)
        divisor /= 10
      }
    }

    if let suffix {
      drawText(suffix, color: color)
    }
  }

  private func drawDigit(_ digit: Int, color: SwiftGFX.Color) {
    switch digit {
    case 0: drawText("0", color: color)
    case 1: drawText("1", color: color)
    case 2: drawText("2", color: color)
    case 3: drawText("3", color: color)
    case 4: drawText("4", color: color)
    case 5: drawText("5", color: color)
    case 6: drawText("6", color: color)
    case 7: drawText("7", color: color)
    case 8: drawText("8", color: color)
    default: drawText("9", color: color)
    }
  }
}
