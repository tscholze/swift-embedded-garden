/// Firmware entry point selected by the C bootstrap.
///
/// Switch the invoked sample to select a different firmware demonstration.
@_cdecl("swift_main")
public func swift_main() -> Never {
  // Run Main and combined sample.
  // For everything else, have a look at the other samples
  // in Sources/Application/Samples and call them here.
  Sample().run()
}
