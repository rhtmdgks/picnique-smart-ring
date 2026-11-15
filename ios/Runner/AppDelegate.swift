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
  private var backendChannel: FlutterMethodChannel?
  private var selectedBackend: String?

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
    // Dart owns backend initialization; the retired IosBleBridge stays disabled.
    backendChannel = FlutterMethodChannel(name: "picnique/backend", binaryMessenger: messenger)
    backendChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "backend_unavailable", message: "Application delegate unavailable", details: nil))
        return
      }
      guard call.method == "selectBackend" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: Any],
            let backend = args["backend"] as? String,
            backend == "qring" || backend == "rwfit" else {
        result(FlutterError(code: "invalid_backend", message: "Unknown BLE backend", details: nil)); return
      }
      if let selected = self.selectedBackend, selected != backend {
        result(FlutterError(code: "backend_locked", message: "Restart to change BLE backend", details: nil)); return
      }
      self.selectedBackend = backend
      result(true)
    }
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
