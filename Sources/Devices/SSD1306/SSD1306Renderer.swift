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
      display.drawText("Temperature - \(reading.temperatureC)C")
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("Humidity    - \(reading.humidityPercent)P")
    } else {
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("No reading", color: .on)
    }

    _ = display.flush()
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
      display.drawText("T - \(reading.temperatureC)C")
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("H - \(reading.humidityPercent)P")
    } else {
      display.setCursor(x: 4 + shiftX, y: 38 + shiftY)
      display.drawText("NA", color: .on)
    }

    _ = display.flush()
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
