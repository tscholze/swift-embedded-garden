/// A sample that demonstrates a variety of features,
/// including many accessories, such as a rotary encoder,
/// traffic light, DHT11 sensor, SSD1306 display, and buzzer.
class Sample {
  // MARK: - Pin Assignments -

  private let rbc = RotaryButtonConfiguration(dtPin: 14, clkPin: 15)
  private let tlc = TrafficLightConfiguration(redPin: 2, yellowPin: 3, greenPin: 4)
  private let dht11c = DHT11Configuration(dataPin: 22)
  private let ssd1306c = SSD1306Configuration(i2cAddress: 0x3c, sdaPin: 12, sclPin: 13)
  private let buzzerc = BuzzerConfiguration(triggerPin: 28)
  private let buttonc = ButtonConfiguration(triggerPin: 16)

  // MARK: - Peripherals -

  private var renderer: SSD1306Renderer!
  private var display: SSD1306Driver!
  private var trafficLight: TrafficLight!
  private var buzzer: Buzzer!

  // MARK: - Sample -

  /// Runs the sample, which demonstrates rotary encoder input,
  ///  traffic light output, and SSD1306 display rendering.
  func run() -> Never {
    // Setup DHT11 sensor
    let dht11Sensor = DHT11(configuration: dht11c)

    // Setup rotary button
    let rotaryButton = RotaryButton(configuration: rbc)

    // Setup button
    let button = Button(configuration: buttonc)

    // Setup buzzer
    buzzer = Buzzer(configuration: buzzerc)

    // Setup traffic light
    trafficLight = TrafficLight(configuration: tlc)

    // Setup display
    display = SSD1306Driver(configuration: ssd1306c)

    // Initialize the display and check for errors.
    // If initialization fails, enter a fault loop.
    if case .failure = display.initialize() {
      displayFaultLoop(blinks: 1)
    }

    // Configure renderer
    renderer = SSD1306Renderer(display: display)

    // Wait that everything is ready before starting the main loop.
    pico_delay_ms(2_000)

    // Draw the initial frame and send it to the display.
    render(activeLight: .off, reading: try? dht11Sensor.read())

    var position = 0

    // Start never ending looping
    while true {
      showCycleIndicator()

      /// 1. Check if the button is pressed.
      /// If it is, increment the position by 1.
      ///
      /// 2. If the button is not pressed,
      /// check if the rotary encoder has been turned.
      if button.isPressed() {
        position += 1
      } else {
        guard let direction = rotaryButton.waitForDirection() else { continue }
        position += direction
      }

      /// 3. Read the DHT11 sensor to get the current
      ///  temperature and humidity.
      var reading: DHT11Reading? = nil
      do {
        reading = try dht11Sensor.read()
      } catch {
        displayFaultLoop(blinks: 3)
      }

      // 4. Apply coloring
      switch abs(position) {
      case 0:
        showRed(reading: reading)
      case 1:
        showYellow(reading: reading)
      case 2:
        showGreen(reading: reading)
        position = 0
      default:
        render(activeLight: .off, reading: reading)
      }

      // small debounce delay
      pico_delay_ms(250)
    }
  }

  // MARK: - Rendering -

  /// Triggeres a new render cycle for the display
  ///
  /// - Parameters:
  ///   - activeLight: The light to illuminate.
  ///   - reading: The optional DHT11 sensor reading.
  private func render(activeLight: TrafficLightColor, reading: DHT11Reading? = nil) {
    display.clear()
    renderer.drawTitle("Swift Embedded Garden")
    renderer.drawTrafficLight(activeLight: activeLight)

    if let reading {
      renderer.drawReadingShort(reading, shiftX: 30, shiftY: 4)
    }

    guard case .success = display.flush() else {
      displayFaultLoop(blinks: 2)
    }

    buzzer.buzz()
  }

  // MARK: - Helper -

  /// Show a brief indicator on the onboard LED to
  /// signal a cycle change.
  private func showCycleIndicator() {
    RP2040GPIO.setHigh(pin: 25)
    pico_delay_ms(100)
    RP2040GPIO.setLow(pin: 25)
  }

  /// Show the red light on, and turn off yellow and green lights.
  private func showRed(reading: DHT11Reading? = nil) {
    trafficLight.showRed()
    render(activeLight: .red, reading: reading)
  }

  /// Show the yellow light on, and turn off red and green lights.
  private func showYellow(reading: DHT11Reading? = nil) {
    trafficLight.showYellow()
    render(activeLight: .yellow, reading: reading)
  }

  /// Show the green light on, and turn off red and yellow lights.
  private func showGreen(reading: DHT11Reading? = nil) {
    trafficLight.showGreen()
    render(activeLight: .green, reading: reading)
  }

  /// Signals a display failure on the Pico onboard LED without requiring UART.
  ///
  /// - Parameter blinks: Number of short pulses emitted before each long pause.
  private func displayFaultLoop(blinks: UInt32) -> Never {
    let ledPin: UInt32 = 25
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)
    while true {
      for _ in 0..<blinks {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(120)
        RP2040GPIO.setLow(pin: ledPin)
        pico_delay_ms(180)
      }
      pico_delay_ms(1_000)
    }
  }
}
