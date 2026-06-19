import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bleBridge: IosBleBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: IosBleBridge.bgTaskId,
      using: nil
    ) { task in
      self.handleRingBackgroundSync(task: task as! BGAppRefreshTask)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    DispatchQueue.main.async { [weak self] in
      guard self?.bleBridge == nil else { return }
      self?.bleBridge = IosBleBridge(messenger: messenger)
    }
  }

  private func handleRingBackgroundSync(task: BGAppRefreshTask) {
    IosBleBridge.scheduleBackgroundSync()

    let work = DispatchWorkItem { [weak self] in
      guard let bridge = self?.bleBridge else {
        task.setTaskCompleted(success: false)
        return
      }
      bridge.performBackgroundHealthSync { ok in
        task.setTaskCompleted(success: ok)
      }
    }

    task.expirationHandler = {
      work.cancel()
    }

    DispatchQueue.main.async(execute: work)
  }
}
