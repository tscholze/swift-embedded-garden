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

        blinkSequence()
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
        while true {
            showCycleIndicator()

            pico_delay_ms(250)
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
