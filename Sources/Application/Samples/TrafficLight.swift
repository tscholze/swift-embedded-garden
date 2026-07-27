struct TrafficLight {
    // MARK: - Sample -

    func run() -> Never {
        blinkSequence()
    }

    // MARK: - Traffic Light Simulation -

    private func blinkSequence() -> Never {
        let ledPin = PicoBoard.onboardLEDPin

        let redPin = UInt32(2)
        let yellowPin = UInt32(3)
        let greenPin = UInt32(4)

        RP2040GPIO.configureAsSIOOutput(pin: ledPin)
        RP2040GPIO.configureAsSIOOutput(pin: redPin)
        RP2040GPIO.configureAsSIOOutput(pin: yellowPin)
        RP2040GPIO.configureAsSIOOutput(pin: greenPin)

        while true {
            // Indicate a new cycle
            RP2040GPIO.setHigh(pin: ledPin)
            pico_delay_ms(250)
            RP2040GPIO.setLow(pin: ledPin)

            // Red on, others off
            RP2040GPIO.setHigh(pin: redPin)
            RP2040GPIO.setLow(pin: yellowPin)
            RP2040GPIO.setLow(pin: greenPin)
            pico_delay_ms(1000)

            // Yellow on, others off
            RP2040GPIO.setLow(pin: redPin)
            RP2040GPIO.setHigh(pin: yellowPin)
            RP2040GPIO.setLow(pin: greenPin)
            pico_delay_ms(1000)

            // Green on, others off
            RP2040GPIO.setLow(pin: redPin)
            RP2040GPIO.setLow(pin: yellowPin)
            RP2040GPIO.setHigh(pin: greenPin)
            pico_delay_ms(1000)
        }
    }
}
