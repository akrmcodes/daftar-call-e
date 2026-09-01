import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.akrmcodes.daftar.backup.periodic",
      frequency: NSNumber(value: 30 * 60)
    )
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "com.akrmcodes.daftar.backup.chain"
    )
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "com.akrmcodes.daftar.backup.processing"
    )
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "com.akrmcodes.daftar.backup.queue_drain"
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
