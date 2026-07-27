struct TrafficLight {
    // MARK: - GPIO Pin Assignments -

    private let ledPin = PicoBoard.onboardLEDPin
    private let redPin = UInt32(2)
    private let yellowPin = UInt32(3)
    private let greenPin = UInt32(4)

    // MARK: - Sample -

    func run() -> Never {
        RP2040GPIO.configureAsSIOOutput(pin: ledPin)
        RP2040GPIO.configureAsSIOOutput(pin: redPin)
        RP2040GPIO.configureAsSIOOutput(pin: yellowPin)
        RP2040GPIO.configureAsSIOOutput(pin: greenPin)

        // Use rotary encoder (KY-040) to change the active traffic light.
        // Wiring (example):
        // KY-040 GND -> Pico GND
        // KY-040 +   -> Pico 3.3V
        // KY-040 DT  -> Pico GPIO14
        // KY-040 CLK -> Pico GPIO15
        // KY-040 MS  -> Pico GPIO13 (optional switch)
        // The encoder is read by waiting for CLK edges and sampling DT to
        // determine direction. The selected light is `position % 3`.
        blinkWithKnob()
    }

    // MARK: - Traffic Light Simulation -

    private func blinkSequence() -> Never {
        while true {
            showCycleIndicator()

            showRed()
            pico_delay_ms(1000)
            showYellow()
            pico_delay_ms(1000)
            showGreen()
            pico_delay_ms(1000)
        }
    }

    private func blinkWithKnob() -> Never {
        // Encoder pin assignments (change if you wired differently)
        let dtPin: UInt32 = 14
        let clkPin: UInt32 = 15
        let swPin: UInt32 = 13 // push switch (optional)

        // Configure encoder pins as inputs with pull-ups (typical wiring)
        RP2040GPIO.configureAsSIOInput(pin: dtPin)
        RP2040GPIO.enablePadPullUp(pin: dtPin)
        RP2040GPIO.configureAsSIOInput(pin: clkPin)
        RP2040GPIO.enablePadPullUp(pin: clkPin)
        RP2040GPIO.configureAsSIOInput(pin: swPin)
        RP2040GPIO.enablePadPullUp(pin: swPin)

        var position: Int = 0

        // show initial state
        applyPosition(position)

        while true {
            showCycleIndicator()
            
            // Wait for rising edge on CLK (blocks).
            _ = RP2040GPIO.waitForRisingEdge(pin: clkPin, timeoutMs: 10_000)

            // read DT to determine direction; typical rule: when CLK rises,
            // if DT!=CLK then direction is one way, otherwise the other.
            let dtHigh = RP2040GPIO.read(pin: dtPin)
            let clkHigh = RP2040GPIO.read(pin: clkPin)

            if dtHigh != clkHigh {
                position += 1
            } else {
                position -= 1
            }

            // apply modulo 3 mapping: 0 -> red, 1 -> yellow, 2 -> green
            applyPosition(position)

            // small debounce delay
            pico_delay_ms(250)
        }
    }

    private func applyPosition(_ position: Int) {
        let modulo = ((position % 3) + 3) % 3
        switch modulo {
        case 0: showRed()
        case 1: showYellow()
        case 2: showGreen()
        default: showRed()
        }
    }

    // MARK: - Helper -

    private func showCycleIndicator() {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(250)
        RP2040GPIO.setLow(pin: ledPin)
    }

    private func showRed() {
        RP2040GPIO.setHigh(pin: redPin)
        RP2040GPIO.setLow(pin: yellowPin)
        RP2040GPIO.setLow(pin: greenPin)
    }

    private func showYellow() {
        RP2040GPIO.setLow(pin: redPin)
        RP2040GPIO.setHigh(pin: yellowPin)
        RP2040GPIO.setLow(pin: greenPin)
    }

    private func showGreen() {
        RP2040GPIO.setLow(pin: redPin)
        RP2040GPIO.setLow(pin: yellowPin)
        RP2040GPIO.setHigh(pin: greenPin)
    }
}
