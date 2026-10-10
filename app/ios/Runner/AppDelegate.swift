import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure iOS Background Audio session for riding intercom (locked screen & Bluetooth)
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [
          .allowBluetooth,
          .allowBluetoothA2DP,
          .defaultToSpeaker,
          .mixWithOthers
        ]
      )
      try audioSession.setActive(true)
    } catch {
      print("Failed to configure background AVAudioSession: \(error)")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
