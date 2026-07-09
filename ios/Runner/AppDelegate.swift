import Flutter
import UIKit
import BackgroundTasks

/// Dart-only BLE companion — native keepalive/pending queue stubs (no OEM SDK).
private final class RingHealthEventStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "kr.picnique.smartring.ring-sync",
      using: nil
    ) { task in
      task.setTaskCompleted(success: true)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let bgChannel = FlutterMethodChannel(
      name: "com.example.picnique_ring/background_keepalive",
      binaryMessenger: messenger
    )
    bgChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "startBackgroundKeepalive", "stopBackgroundKeepalive", "clearPendingHealthRecords":
        result(true)
      case "fetchPendingHealthSnapshot":
        result(["records": [], "fetchedLineCount": 0])
      case "fetchPendingHealthRecords":
        result([])
      case "replacePendingHealthRecords":
        result(true)
      case "collectPendingHealthNow":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let healthEvents = FlutterEventChannel(
      name: "com.example.picnique_ring/health_events",
      binaryMessenger: messenger
    )
    healthEvents.setStreamHandler(RingHealthEventStreamHandler())
  }
}
