/// Demonstrates using the Buzzer device.
struct BuzzerSample {

  // MARK: - Sample run -

  func run() -> Never {

    let buzzer = Buzzer(configuration: BuzzerConfiguration(triggerPin: 28))

    while true {
      buzzer.buzz()
      pico_delay_ms(1_000)
      buzzer.buzz()
      pico_delay_ms(1_000)
    }
  }
}
