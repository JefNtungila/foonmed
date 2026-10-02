import CoreHaptics
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let hapticController = ContactHapticController()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "foonmed/vibrator",
      binaryMessenger: messenger)
    let haptics = hapticController
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(CHHapticEngine.capabilitiesForHaptics().supportsHaptics)
      case "start":
        let args = call.arguments as? [String: Any]
        let durationMs = (args?["durationMs"] as? NSNumber)?.intValue ?? 500
        haptics.start(durationMs: durationMs, result: result)
      case "stop":
        haptics.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

class ContactHapticController {
  private var engine: CHHapticEngine?
  private var activePlayer: CHHapticAdvancedPatternPlayer?

  func start(durationMs: Int, result: @escaping FlutterResult) {
    guard CHHapticEngine.capabilitiesForHaptics().supportsHaptics else {
      result(
        FlutterError(
          code: "unsupported",
          message: "This device does not support haptics",
          details: nil))
      return
    }

    do {
      stop()
      let engine = try CHHapticEngine()
      engine.isAutoShutdownEnabled = true
      engine.resetHandler = { [weak self] in
        try? self?.engine?.start()
      }
      try engine.start()
      self.engine = engine

      let duration = TimeInterval(durationMs) / 1000.0
      let continuous = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
        ],
        relativeTime: 0,
        duration: duration)
      let pattern = try CHHapticPattern(events: [continuous], parameters: [])
      let player = try engine.makeAdvancedPlayer(with: pattern)
      player.completion = { [weak self] _ in
        self?.activePlayer = nil
      }
      try player.start(atTime: CHHapticTimeImmediate)
      activePlayer = player
      result(nil)
    } catch {
      stop()
      result(
        FlutterError(
          code: "haptic_error",
          message: error.localizedDescription,
          details: nil))
    }
  }

  func stop() {
    if let player = activePlayer {
      try? player.stop(atTime: CHHapticTimeImmediate)
    }
    activePlayer = nil
    engine?.stop(completionHandler: nil)
    engine = nil
  }
}
