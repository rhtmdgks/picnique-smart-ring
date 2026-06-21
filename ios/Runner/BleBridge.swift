import Foundation
import CoreBluetooth
import Flutter
import QCBandSDK
import BackgroundTasks
import UserNotifications

// MARK: - Background prefs & pending queue

enum IosPendingHealthQueue {
  private static let fileName = "ring_pending_health.jsonl"

  private static var fileURL: URL {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return dir.appendingPathComponent(fileName)
  }

  static func append(_ record: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: record),
          let line = String(data: data, encoding: .utf8) else { return }
    let url = fileURL
    if FileManager.default.fileExists(atPath: url.path),
       let handle = try? FileHandle(forWritingTo: url) {
      handle.seekToEndOfFile()
      if let bytes = (line + "\n").data(using: .utf8) {
        handle.write(bytes)
      }
      try? handle.close()
    } else {
      try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
  }

  static func readAll() -> [[String: Any]] {
    let url = fileURL
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    var rows: [[String: Any]] = []
    for line in text.split(separator: "\n") {
      guard let data = line.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        continue
      }
      rows.append(obj)
    }
    return rows
  }

  static func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }

  static func replaceAll(_ records: [[String: Any]]) {
    if records.isEmpty {
      clear()
      return
    }
    var text = ""
    for record in records {
      guard let data = try? JSONSerialization.data(withJSONObject: record),
            let line = String(data: data, encoding: .utf8) else { continue }
      text += line + "\n"
    }
    try? text.write(to: fileURL, atomically: true, encoding: .utf8)
  }
}

enum IosRingBackgroundAlertPrefs {
  private static let enabledKey = "flutter.battery_low_alert_enabled"

  static var isBatteryLowAlertEnabled: Bool {
    let d = UserDefaults.standard
    if d.object(forKey: enabledKey) == nil { return true }
    return d.bool(forKey: enabledKey)
  }
}

enum IosRingBackgroundPrefs {
  private static let enabledKey = "ring_keepalive_enabled"
  private static let addressKey = "ring_keepalive_address"
  private static let nameKey = "ring_keepalive_name"

  static func setKeepalive(enabled: Bool, address: String?, name: String?) {
    let d = UserDefaults.standard
    d.set(enabled, forKey: enabledKey)
    if enabled, let address, !address.isEmpty {
      d.set(address, forKey: addressKey)
      d.set(name ?? "", forKey: nameKey)
    } else {
      d.removeObject(forKey: addressKey)
      d.removeObject(forKey: nameKey)
    }
  }

  static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
  static var address: String? { UserDefaults.standard.string(forKey: addressKey) }
}

enum IosRingMeasurementPolicy {
  static let ringAutoHeartIntervalMinutes = 10
  static let appCollectIntervalSec = ringAutoHeartIntervalMinutes * 60
  static let minCollectGapMs = appCollectIntervalSec * 1000
}

enum IosRingCollectionWatermark {
  private static let heartDayKey = "ring_collect_heart_day"
  private static let heartThroughKey = "ring_collect_heart_through"
  private static let lastCollectKey = "ring_collect_last_ms"

  static func heartSampleThroughIndex() -> Int {
    let d = UserDefaults.standard
    let today = Self.todayString()
    if d.string(forKey: heartDayKey) != today { return -1 }
    return d.integer(forKey: heartThroughKey)
  }

  static func setHeartSampleThroughIndex(_ index: Int) {
    let d = UserDefaults.standard
    d.set(Self.todayString(), forKey: heartDayKey)
    d.set(index, forKey: heartThroughKey)
  }

  static func markCollected() {
    UserDefaults.standard.set(
      Int(Date().timeIntervalSince1970 * 1000),
      forKey: lastCollectKey
    )
  }

  static func lastCollectMs() -> Int {
    UserDefaults.standard.integer(forKey: lastCollectKey)
  }

  private static let lastBatteryKey = "ring_collect_last_battery_ms"
  private static let batteryIntervalMs = 3 * 60 * 1000

  static func shouldCheckBattery(nowMs: Int = Int(Date().timeIntervalSince1970 * 1000)) -> Bool {
    let last = UserDefaults.standard.integer(forKey: lastBatteryKey)
    return last <= 0 || nowMs - last >= batteryIntervalMs
  }

  static func markBatteryChecked(nowMs: Int = Int(Date().timeIntervalSince1970 * 1000)) {
    UserDefaults.standard.set(nowMs, forKey: lastBatteryKey)
  }

  private static func todayString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f.string(from: Date())
  }
}

// iOS counterpart of android BleBridge focused on scan/connect + health sync.

private final class HealthEventStreamHandler: NSObject, FlutterStreamHandler {
  weak var bridge: IosBleBridge?

  init(bridge: IosBleBridge) {
    self.bridge = bridge
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    bridge?.setHealthEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    bridge?.setHealthEventSink(nil)
    return nil
  }
}

final class IosBleBridge: NSObject {
  static let bgTaskId = "kr.picnique.smartring.ring-sync"
  private static let centralRestoreId = "kr.picnique.smartring.central"

  private enum ScanState {
    case idle, scanning
  }

  private let methodChannelName = "com.example.picnique_ring/ble"
  private let eventChannelName = "com.example.picnique_ring/ble_events"
  private let fgChannelName = "com.example.picnique_ring/foreground_service_channel"
  private let bgChannelName = "com.example.picnique_ring/background_keepalive"
  private let chargingLiveActivityChannelName =
    "com.example.picnique_ring/charging_live_activity"

  private let healthEventChannelName = "com.example.picnique_ring/health_events"

  private var methodChannel: FlutterMethodChannel!
  private var eventChannel: FlutterEventChannel!
  private var healthEventChannel: FlutterEventChannel!
  private var fgChannel: FlutterMethodChannel!
  private var bgChannel: FlutterMethodChannel!
  private var chargingLiveActivityChannel: FlutterMethodChannel!

  private var eventSink: FlutterEventSink?

  private var _central: CBCentralManager?

  private var central: CBCentralManager {
    if let c = _central { return c }
    let c = CBCentralManager(
      delegate: self,
      queue: nil,
      options: [CBCentralManagerOptionRestoreIdentifierKey: Self.centralRestoreId]
    )
    _central = c
    return c
  }

  private var peripherals: [UUID: CBPeripheral] = [:]
  private var connected: CBPeripheral?
  private var scanState: ScanState = .idle
  private var scanPrefix: String?
  private var pendingConnect: FlutterResult?
  private var pendingDisconnect: FlutterResult?
  private var pendingFreshReconnectPeripheral: CBPeripheral?
  private var connectTimeoutWork: DispatchWorkItem?
  private var keepaliveTimer: Timer?
  private var keepaliveConnectInFlight = false
  private var keepaliveConnectCompletion: ((Bool) -> Void)?
  private var backgroundCollectTimer: Timer?
  private var backgroundCollectInFlight = false

  private var realtimeStepHooked = false
  private var realtimeBatteryHooked = false
  private var lastLowBatteryNotified: Int?
  private var healthEventSink: FlutterEventSink?
  private let mainQueue = DispatchQueue.main

  private func invokeFlutterResult(_ result: @escaping FlutterResult, _ value: Any?) {
    if Thread.isMainThread {
      result(value)
    } else {
      mainQueue.async { result(value) }
    }
  }

  init(messenger: FlutterBinaryMessenger) {
    super.init()

    RingMeasurementSession.shared.delegate = self

    methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler(handle)

    eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    eventChannel.setStreamHandler(self)

    healthEventChannel = FlutterEventChannel(name: healthEventChannelName, binaryMessenger: messenger)
    healthEventChannel.setStreamHandler(HealthEventStreamHandler(bridge: self))

    fgChannel = FlutterMethodChannel(name: fgChannelName, binaryMessenger: messenger)
    fgChannel.setMethodCallHandler(handleForeground)

    bgChannel = FlutterMethodChannel(name: bgChannelName, binaryMessenger: messenger)
    bgChannel.setMethodCallHandler(handleBackgroundKeepalive)

    chargingLiveActivityChannel = FlutterMethodChannel(
      name: chargingLiveActivityChannelName,
      binaryMessenger: messenger
    )
    chargingLiveActivityChannel.setMethodCallHandler(handleChargingLiveActivity)

    DispatchQueue.main.async { [weak self] in
      self?.resumeKeepaliveIfNeeded()
    }
  }

  // MARK: - Background connection keepalive (bluetooth-central)

  /// 앱 종료·백그라운드에서도 BLE 연결을 유지·복구한다 (Android ForegroundService와 동일 목적).
  func resumeKeepaliveIfNeeded() {
    guard IosRingBackgroundPrefs.isEnabled else {
      stopKeepaliveConnectionMaintenance()
      return
    }
    _ = central
    startKeepaliveConnectionMaintenance()
    startBackgroundDataCollection()
    ensureKeepaliveConnected()
    Self.scheduleBackgroundSync()
  }

  private func startBackgroundDataCollection() {
    backgroundCollectTimer?.invalidate()
    backgroundCollectTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(IosRingMeasurementPolicy.appCollectIntervalSec), repeats: true) { [weak self] _ in
      self?.collectHealthRecordsIfConnected(force: false)
    }
    if let timer = backgroundCollectTimer {
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  private func stopBackgroundDataCollection() {
    backgroundCollectTimer?.invalidate()
    backgroundCollectTimer = nil
  }

  func setHealthEventSink(_ sink: FlutterEventSink?) {
    healthEventSink = sink
  }

  private func emitHealthDataReady() {
    healthEventSink?(["type": "healthDataReady"])
  }

  /// 연결된 상태에서 반지 저장소 → pending 큐 (Session idle일 때만).
  private func collectHealthRecordsIfConnected(force: Bool) {
    guard IosRingBackgroundPrefs.isEnabled,
          connected?.state == .connected else { return }

    RingMeasurementSession.shared.collectHealthIfIdle(force: force) { _ in }
  }

  private func startKeepaliveConnectionMaintenance() {
    keepaliveTimer?.invalidate()
    keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      self?.ensureKeepaliveConnected()
      self?.checkBatteryStatusIfConnected(force: false)
    }
    if let timer = keepaliveTimer {
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  private func stopKeepaliveConnectionMaintenance() {
    keepaliveTimer?.invalidate()
    keepaliveTimer = nil
    stopBackgroundDataCollection()
  }

  private func ensureKeepaliveConnected() {
    guard IosRingBackgroundPrefs.isEnabled,
          pendingConnect == nil,
          !keepaliveConnectInFlight,
          central.state == .poweredOn,
          let address = IosRingBackgroundPrefs.address,
          let uuid = UUID(uuidString: address) else {
      return
    }

    if let peripheral = connected, peripheral.state == .connected {
      keepaliveConnectInFlight = true
      QCSDKManager.shareInstance().add(peripheral) { [weak self] ok in
        guard let self = self else { return }
        self.keepaliveConnectInFlight = false
        if !ok {
          self.connectKeepalivePeripheral(uuid: uuid)
        }
      }
      return
    }

    connectKeepalivePeripheral(uuid: uuid)
  }

  private func connectKeepalivePeripheral(uuid: UUID) {
    guard !keepaliveConnectInFlight, pendingConnect == nil else { return }
    guard let peripheral = resolveKnownPeripheral(uuid: uuid) else { return }

    keepaliveConnectInFlight = true
    peripherals[uuid] = peripheral
    connected = peripheral
    peripheral.delegate = self

    let complete: (Bool) -> Void = { [weak self] ok in
      guard let self = self else { return }
      self.keepaliveConnectInFlight = false
      self.keepaliveConnectCompletion = nil
      if ok {
        self.emit([
          "type": "connected",
          "address": peripheral.identifier.uuidString,
          "name": peripheral.name ?? "",
        ])
        self.collectHealthRecordsIfConnected(force: true)
        self.checkBatteryStatusIfConnected(force: true)
      }
    }

    if peripheral.state == .connected {
      QCSDKManager.shareInstance().add(peripheral) { [weak self] ok in
        guard let self = self else { return }
        if ok {
          complete(true)
        } else {
          self.keepaliveConnectCompletion = complete
          self.pendingFreshReconnectPeripheral = peripheral
          QCSDKManager.shareInstance().removeAllPeripheral()
          self.central.cancelPeripheralConnection(peripheral)
        }
      }
      return
    }

    keepaliveConnectCompletion = complete
    central.connect(peripheral, options: nil)

    connectTimeoutWork?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      self.keepaliveConnectInFlight = false
      self.keepaliveConnectCompletion?(false)
      self.keepaliveConnectCompletion = nil
    }
    connectTimeoutWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
  }

  private func scheduleKeepaliveReconnectAfterDisconnect() {
    guard IosRingBackgroundPrefs.isEnabled, pendingDisconnect == nil else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      self?.ensureKeepaliveConnected()
    }
  }

  /// 연결 유지 중 3분마다 배터리 %·충전 상태를 pending 큐에 적재한다.
  private func checkBatteryStatusIfConnected(force: Bool) {
    guard IosRingBackgroundPrefs.isEnabled,
          connected?.state == .connected else { return }
    if !force && !IosRingCollectionWatermark.shouldCheckBattery() { return }

    QCSDKCmdCreator.readBatterySuccess({ [weak self] battery, charging in
      guard let self = self else { return }
      let level = Int(battery)
      guard level > 0 else { return }

      IosRingCollectionWatermark.markBatteryChecked()
      let iso = ISO8601DateFormatter()
      let collectedAt = iso.string(from: Date())
      IosPendingHealthQueue.append([
        "type": "battery",
        "date": collectedAt,
        "battery": level,
        "level": level,
        "charging": charging,
      ])
      self.maybeNotifyLowBattery(level)
      if #available(iOS 16.2, *) {
        RingChargingLiveActivityManager.sync(isCharging: charging, battery: level)
      }
    }, failed: {})
  }

  private func handleChargingLiveActivity(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "syncChargingActivity" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let isCharging = args?["isCharging"] as? Bool ?? false
    let battery = args?["battery"] as? Int ?? 0
    if #available(iOS 16.2, *) {
      RingChargingLiveActivityManager.sync(isCharging: isCharging, battery: battery)
      result(true)
    } else {
      result(false)
    }
  }

  // MARK: - Handlers
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startScan":
      let prefix = (call.arguments as? [String: Any])?["namePrefix"] as? String
      let timeout = (call.arguments as? [String: Any])?["timeoutMs"] as? Int ?? 10_000
      startScan(namePrefix: prefix, timeoutMs: timeout, result: result)
    case "stopScan":
      stopScan(result: result)
    case "getBluetoothState":
      result(bluetoothStateString())
    case "connectDirectly":
      let addr = (call.arguments as? [String: Any])?["deviceAddress"] as? String
      connectDirectly(deviceAddress: addr, result: result)
    case "reconnectKnownDevice":
      let addr = (call.arguments as? [String: Any])?["deviceAddress"] as? String
      reconnectKnownDevice(deviceAddress: addr, result: result)
    case "disconnect":
      disconnect(result: result)
    case "getBatteryLevel":
      getBatteryLevel(result: result)
    case "syncTimeAndGetCoreFeatures":
      syncTimeAndGetCoreFeatures(result: result)
    case "readHw":
      readHardwareRevision(result: result)
    case "readFw":
      readFirmwareRevision(result: result)
    case "readHrSetting":
      readHrSetting(result: result)
    case "writeHrSetting":
      let isEnable = (call.arguments as? [String: Any])?["isEnable"] as? Bool ?? false
      let interval = (call.arguments as? [String: Any])?["interval"] as? Int
        ?? IosRingMeasurementPolicy.ringAutoHeartIntervalMinutes
      writeHrSetting(isEnable: isEnable, interval: interval, result: result)
    case "readSpo2Setting":
      readSpo2Setting(result: result)
    case "writeSpo2Setting":
      let isEnable = (call.arguments as? [String: Any])?["isEnable"] as? Bool ?? false
      writeSpo2Setting(isEnable: isEnable, result: result)
    case "readBpSetting":
      readBpSetting(result: result)
    case "writeBpSetting":
      let args = (call.arguments as? [String: Any]) ?? [:]
      let isEnable = args["isEnable"] as? Bool ?? false
      let sh = args["startHour"] as? Int ?? 9
      let sm = args["startMinute"] as? Int ?? 0
      let eh = args["endHour"] as? Int ?? 21
      let em = args["endMinute"] as? Int ?? 0
      let multiple = args["multiple"] as? Int ?? 60
      writeBpSetting(
        isEnable: isEnable,
        startHour: sh,
        startMinute: sm,
        endHour: eh,
        endMinute: em,
        multiple: multiple,
        result: result
      )
    case "readPressureSetting":
      readPressureSetting(result: result)
    case "writePressureSetting":
      let isEnable = (call.arguments as? [String: Any])?["isEnable"] as? Bool ?? false
      writePressureSetting(isEnable: isEnable, result: result)
    case "readHrvSetting":
      readHrvSetting(result: result)
    case "writeHrvSetting":
      let isEnable = (call.arguments as? [String: Any])?["isEnable"] as? Bool ?? true
      writeHrvSetting(isEnable: isEnable, result: result)
    case "enableRealtimeNotifications", "enableRealtime":
      enableRealtimeNotifications(result: result)
    case "disableRealtimeNotifications", "disableRealtime":
      disableRealtimeNotifications(result: result)
    case "syncSleepNew":
      let offset = (call.arguments as? [String: Any])?["offset"] as? Int ?? 0
      syncSleepNew(offset: offset, result: result)
    case "syncSleepDisplay":
      let offset = (call.arguments as? [String: Any])?["dayOffset"] as? Int ?? 0
      syncSleepDisplay(dayOffset: offset, result: result)
    case "syncHeartRate":
      syncHeartRate(nowTime: (call.arguments as? [String: Any])?["nowTime"] as? Int, result: result)
    case "syncTodaySport":
      syncTodaySport(result: result)
    case "syncSportDetail":
      let offset = (call.arguments as? [String: Any])?["dayOffset"] as? Int ?? 0
      syncSportDetail(dayOffset: offset, result: result)
    case "syncSedentary":
      let offset = (call.arguments as? [String: Any])?["offset"] as? Int ?? 0
      syncSedentary(offset: offset, result: result)
    case "syncBloodOxygen":
      syncBloodOxygen(result: result)
    case "syncManualBloodOxygen":
      syncManualBloodOxygen(result: result)
    case "syncPressure":
      let offset = (call.arguments as? [String: Any])?["offset"] as? Int ?? 0
      syncPressure(offset: offset, result: result)
    case "syncManualPressure":
      syncManualPressure(result: result)
    case "syncManualHeartRate":
      syncManualHeartRate(result: result)
    case "executeManualMeasurement":
      executeManualMeasurement(call: call, result: result)
    case "isMeasurementBusy":
      result(RingMeasurementSession.shared.isBusy)
    case "resetMeasurementSession":
      RingMeasurementSession.shared.abortManualAndReset()
      result(true)
    case "collectHealthIfIdle":
      let force = (call.arguments as? [String: Any])?["force"] as? Bool ?? false
      RingMeasurementSession.shared.collectHealthIfIdle(force: force) { ok in
        result(ok)
      }
    case "syncAutoBp":
      syncAutoBp(result: result)
    case "syncManualBp":
      syncManualBp(result: result)
    case "syncHrv":
      let offset = (call.arguments as? [String: Any])?["offset"] as? Int ?? 0
      syncHrv(offset: offset, result: result)
    case "syncManualHrv":
      syncManualHrv(result: result)
    case "registerTempCallback":
      registerTempCallback(result: result)
    case "syncAutoTemperature":
      let days = (call.arguments as? [String: Any])?["days"] as? Int ?? 2
      syncAutoTemperature(days: days, result: result)
    case "syncManualTemperature":
      let offset = (call.arguments as? [String: Any])?["offset"] as? Int ?? 0
      syncManualTemperature(offset: offset, result: result)
    case "ensureIgnoreBatteryOptimizations":
      result(true) // not applicable on iOS
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleForeground(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startService":
      resumeKeepaliveIfNeeded()
      result(true)
    case "stopService":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleBackgroundKeepalive(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startBackgroundKeepalive":
      let args = call.arguments as? [String: Any]
      let address = args?["address"] as? String
      let name = args?["name"] as? String
      IosRingBackgroundPrefs.setKeepalive(enabled: true, address: address, name: name)
      resumeKeepaliveIfNeeded()
      result(true)
    case "stopBackgroundKeepalive":
      IosRingBackgroundPrefs.setKeepalive(enabled: false, address: nil, name: nil)
      stopKeepaliveConnectionMaintenance()
      result(true)
    case "fetchPendingHealthRecords":
      result(IosPendingHealthQueue.readAll())
    case "clearPendingHealthRecords":
      IosPendingHealthQueue.clear()
      result(true)
    case "replacePendingHealthRecords":
      let args = call.arguments as? [String: Any]
      let raw = args?["records"] as? [[String: Any]] ?? []
      IosPendingHealthQueue.replaceAll(raw)
      result(true)
    case "collectPendingHealthNow":
      guard connected?.state == .connected else {
        result(false)
        return
      }
      RingMeasurementSession.shared.collectHealthIfIdle(force: true) { ok in
        result(ok)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func scheduleBackgroundSync() {
    guard IosRingBackgroundPrefs.isEnabled else { return }
    let request = BGAppRefreshTaskRequest(identifier: bgTaskId)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  func performBackgroundHealthSync(completion: @escaping (Bool) -> Void) {
    guard IosRingBackgroundPrefs.isEnabled,
          let address = IosRingBackgroundPrefs.address,
          let uuid = UUID(uuidString: address) else {
      completion(false)
      return
    }

    let runCollect: () -> Void = { [weak self] in
      RingMeasurementSession.shared.collectHealthIfIdle(force: true) { ok in
        self?.checkBatteryStatusIfConnected(force: true)
        completion(ok)
      }
    }

    let reconnect: () -> Void = { [weak self] in
      guard let self = self else {
        completion(false)
        return
      }
      if let peripheral = self.connected {
        QCSDKManager.shareInstance().add(peripheral) { _ in
          runCollect()
        }
      } else {
        runCollect()
      }
    }

    if connected != nil {
      reconnect()
      return
    }

    if let cached = peripherals[uuid] {
      connected = cached
      cached.delegate = self
      central.connect(cached, options: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) { reconnect() }
      return
    }
    if let retrieved = central.retrievePeripherals(withIdentifiers: [uuid]).first {
      peripherals[uuid] = retrieved
      connected = retrieved
      retrieved.delegate = self
      central.connect(retrieved, options: nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) { reconnect() }
      return
    }
    completion(false)
  }

  private func maybeNotifyLowBattery(_ battery: Int) {
    guard IosRingBackgroundAlertPrefs.isBatteryLowAlertEnabled else { return }

    if battery > 20 {
      if battery >= 25 { lastLowBatteryNotified = nil }
      return
    }
    if let last = lastLowBatteryNotified, battery >= last { return }

    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral else {
        return
      }

      let content = UNMutableNotificationContent()
      content.title = "스마트링 배터리 부족"
      content.body = "배터리가 \(battery)%입니다. 충전해 주세요."
      content.sound = .default

      let request = UNNotificationRequest(
        identifier: "battery_low_alert",
        content: content,
        trigger: nil
      )
      UNUserNotificationCenter.current().add(request)
      DispatchQueue.main.async {
        self.lastLowBatteryNotified = battery
      }
    }
  }

  private func collectPendingSamples(done: @escaping () -> Void) {
    guard !backgroundCollectInFlight else {
      done()
      return
    }
    var finished = false
    let finishOnce: () -> Void = { [weak self] in
      guard !finished else { return }
      finished = true
      self?.backgroundCollectInFlight = false
      done()
    }
    mainQueue.asyncAfter(deadline: .now() + 45, execute: finishOnce)
    backgroundCollectInFlight = true
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoFallback = ISO8601DateFormatter()
    let collectedAt = iso.string(from: Date())
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    var pending = 5
    let finish: () -> Void = {
      pending -= 1
      if pending <= 0 {
        finishOnce()
      }
    }

    QCSDKCmdCreator.readBatterySuccess({ [weak self] battery, charging in
      let level = Int(battery)
      IosPendingHealthQueue.append([
        "type": "battery",
        "date": collectedAt,
        "battery": level,
        "level": level,
        "charging": charging,
      ])
      self?.maybeNotifyLowBattery(level)
      finish()
    }, failed: {
      finish()
    })

    QCSDKCmdCreator.getSchedualHeartRateData(with: [startOfDay], success: { models in
      if let model = models.first {
        let heartRates = model.heartRates.map { $0.intValue }
        let interval = max(Int(model.secondInterval), IosRingMeasurementPolicy.appCollectIntervalSec)
        let through = IosRingCollectionWatermark.heartSampleThroughIndex()
        var maxIndex = through
        for (i, bpm) in heartRates.enumerated() where bpm > 0 {
          if i <= through { continue }
          let sampleDate = startOfDay.addingTimeInterval(TimeInterval(i * interval))
          IosPendingHealthQueue.append([
            "type": "heart_sample",
            "date": isoFallback.string(from: sampleDate),
            "bpm": bpm,
          ])
          maxIndex = i
        }
        if maxIndex > through {
          IosRingCollectionWatermark.setHeartSampleThroughIndex(maxIndex)
        }
      }
      finish()
    }, fail: {
      finish()
    })

    self.queueBackgroundSpo2Samples(iso: isoFallback, calendar: calendar, finish: finish)
    self.queueBackgroundStressSamples(iso: isoFallback, calendar: calendar, finish: finish)
    self.queueBackgroundSportSlots(iso: isoFallback, calendar: calendar, finish: finish)
  }

  private func queueBackgroundSpo2Samples(
    iso: ISO8601DateFormatter,
    calendar: Calendar,
    finish: @escaping () -> Void
  ) {
    let dayIndexes = [0, 1, 2]
    var idx = 0

    func fetchNext() {
      guard idx < dayIndexes.count else {
        finish()
        return
      }
      let dayIndex = dayIndexes[idx]
      idx += 1
      QCSDKCmdCreator.getBloodOxygenData(byDayIndex: dayIndex) { data, _ in
        if let list = data as? [QCBloodOxygenModel] {
          var perDay: [Date: (min: [Int], max: [Int])] = [:]
          for item in list {
            guard let date = item.date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let hour = calendar.component(.hour, from: date)
            var record = perDay[dayStart] ?? (
              min: Array(repeating: 0, count: 24),
              max: Array(repeating: 0, count: 24)
            )
            let vMin = Int(item.minSoa2)
            let vMax = Int(item.maxSoa2)
            let v = Int(item.soa2)
            let minVal = vMin > 0 ? vMin : v
            let maxVal = vMax > 0 ? vMax : v
            if minVal > 0 {
              if record.min[hour] == 0 || minVal < record.min[hour] {
                record.min[hour] = minVal
              }
            }
            if maxVal > 0, maxVal > record.max[hour] {
              record.max[hour] = maxVal
            }
            perDay[dayStart] = record
          }
          for (dayStart, arrays) in perDay {
            for hour in 0..<24 {
              let candidate = arrays.max[hour] > 0 ? arrays.max[hour] :
                (arrays.min[hour] > 0 ? arrays.min[hour] : 0)
              if candidate <= 0 { continue }
              let sampleDate = dayStart.addingTimeInterval(TimeInterval(hour * 3600))
              IosPendingHealthQueue.append([
                "type": "spo2_sample",
                "date": iso.string(from: sampleDate),
                "spo2": candidate,
              ])
            }
          }
        }
        fetchNext()
      }
    }
    fetchNext()
  }

  private func queueBackgroundStressSamples(
    iso: ISO8601DateFormatter,
    calendar: Calendar,
    finish: @escaping () -> Void
  ) {
    let offsets = [0, 1, 2]
    var idx = 0

    func fetchNext() {
      guard idx < offsets.count else {
        finish()
        return
      }
      let offset = offsets[idx]
      idx += 1
      QCSDKCmdCreator.getSchedualStressData(withDates: [NSNumber(value: offset)]) { data, _ in
        if let list = data as? [QCStressModel], let model = list.first {
          let rangeMin = max(Int(model.secondInterval) / 60, 1)
          let stresses = model.stresses.map { $0.intValue }
          let dayStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
          )
          let dayEnd = dayStart.addingTimeInterval(86400)
          for (i, value) in stresses.enumerated() where value > 0 {
            let sampleDate = dayStart.addingTimeInterval(TimeInterval(i * rangeMin * 60))
            if sampleDate >= dayEnd { break }
            IosPendingHealthQueue.append([
              "type": "stress_sample",
              "date": iso.string(from: sampleDate),
              "stress": value,
            ])
          }
        }
        fetchNext()
      }
    }
    fetchNext()
  }

  private func queueBackgroundSportSlots(
    iso: ISO8601DateFormatter,
    calendar: Calendar,
    finish: @escaping () -> Void
  ) {
    let offsets = [0, 1, 2]
    var idx = 0

    func fetchNext() {
      guard idx < offsets.count else {
        finish()
        return
      }
      let offset = offsets[idx]
      idx += 1
      QCSDKCmdCreator.getSportDetailData(
        byDay: offset,
        minuteInterval: 15,
        begin: 0,
        end: 95,
        sportDatas: { sports in
          let formatter = DateFormatter()
          formatter.locale = Locale(identifier: "en_US_POSIX")
          formatter.timeZone = TimeZone.current
          formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

          for sport in sports {
            guard let date = formatter.date(from: sport.happenDate) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }
            let hour = comps.hour ?? 0
            let minute = comps.minute ?? 0
            let timeIndex = ((hour * 60) + minute) / 15
            let total = Int(sport.totalStepCount)
            let run = Int(sport.runStepCount)
            let walk = max(total - run, 0)
            if walk <= 0 && run <= 0 { continue }

            var slotComps = DateComponents()
            slotComps.year = y
            slotComps.month = m
            slotComps.day = d
            slotComps.hour = 0
            slotComps.minute = 0
            let dayStart = calendar.date(from: slotComps) ?? date
            let slotDate = dayStart.addingTimeInterval(TimeInterval(timeIndex * 15 * 60))

            IosPendingHealthQueue.append([
              "type": "sport_slot",
              "date": iso.string(from: slotDate),
              "timeIndex": timeIndex,
              "walkSteps": walk,
              "runSteps": run,
              "distance": Int(sport.distance),
              "calorie": Int(sport.calories.rounded()),
            ])
          }
          fetchNext()
        },
        fail: {
          fetchNext()
        }
      )
    }
    fetchNext()
  }

  private func bluetoothStateString() -> String {
    switch central.state {
    case .poweredOn: return "on"
    case .poweredOff: return "off"
    case .unauthorized: return "unauthorized"
    case .unsupported: return "unsupported"
    case .resetting: return "resetting"
    default: return "unknown"
    }
  }

  // MARK: - Scan
  private func startScan(namePrefix: String?, timeoutMs: Int, result: @escaping FlutterResult) {
    guard central.state == .poweredOn else {
      result(FlutterError(code: "BT_OFF", message: "Bluetooth not powered on", details: nil))
      return
    }
    scanPrefix = namePrefix?.lowercased()
    peripherals.removeAll()
    scanState = .scanning

    let services = [QCBANDSDKSERVERUUID1, QCBANDSDKSERVERUUID2]
      .compactMap { CBUUID(string: $0) }
    central.scanForPeripherals(
      withServices: services,
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak self] in
      guard let self = self else { return }
      if self.scanState == .scanning {
        self.stopScan(result: { _ in })
      }
    }
    result(true)
  }

  private func stopScan(result: @escaping FlutterResult) {
    central.stopScan()
    scanState = .idle
    result(true)
  }

  // MARK: - Connect
  private func connectDirectly(deviceAddress: String?, result: @escaping FlutterResult) {
    reconnectKnownDevice(deviceAddress: deviceAddress, result: result)
  }

  private func reconnectKnownDevice(deviceAddress: String?, result: @escaping FlutterResult) {
    guard let addr = deviceAddress, let uuid = UUID(uuidString: addr) else {
      result(FlutterError(code: "BAD_ARGS", message: "deviceAddress(uuidString) required", details: nil))
      return
    }

    guard central.state == .poweredOn else {
      result(FlutterError(code: "BT_OFF", message: "Bluetooth not powered on", details: nil))
      return
    }

    guard let peripheral = resolveKnownPeripheral(uuid: uuid) else {
      result(FlutterError(code: "NOT_FOUND", message: "Peripheral not found for \(addr)", details: nil))
      return
    }

    if scanState == .scanning {
      central.stopScan()
      scanState = .idle
    }

    peripherals[uuid] = peripheral
    connected = peripheral
    peripheral.delegate = self

    if peripheral.state == .connected {
      // OS는 connected지만 SDK 명령(setTime/측정)이 실패하는 '유령 연결'이 잦다.
      // 한 번 끊었다가 didConnect 경로로 재연결해 SDK 핸드셰이크를 새로 맞춘다.
      pendingFreshReconnectPeripheral = peripheral
      pendingConnect = result
      QCSDKManager.shareInstance().removeAllPeripheral()
      central.cancelPeripheralConnection(peripheral)
      connectTimeoutWork?.cancel()
      let work = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        guard let pending = self.pendingConnect else { return }
        pending(FlutterError(code: "CONNECT_TIMEOUT", message: "fresh reconnect timeout", details: nil))
        self.pendingConnect = nil
        self.pendingFreshReconnectPeripheral = nil
      }
      connectTimeoutWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
      return
    }

    pendingConnect = result
    central.connect(peripheral, options: nil)

    connectTimeoutWork?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      guard let pending = self.pendingConnect else { return }
      pending(FlutterError(code: "CONNECT_TIMEOUT", message: "connect timeout", details: nil))
      self.pendingConnect = nil
      if let p = self.connected {
        self.central.cancelPeripheralConnection(p)
      }
    }
    connectTimeoutWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
  }

  private func resolveKnownPeripheral(uuid: UUID) -> CBPeripheral? {
    if let cached = peripherals[uuid] {
      return cached
    }

    let serviceUUIDs = [QCBANDSDKSERVERUUID1, QCBANDSDKSERVERUUID2]
      .compactMap { CBUUID(string: $0) }
    let connectedPeripherals = central.retrieveConnectedPeripherals(withServices: serviceUUIDs)
    if let alreadyConnected = connectedPeripherals.first(where: { $0.identifier == uuid }) {
      return alreadyConnected
    }

    return central.retrievePeripherals(withIdentifiers: [uuid]).first
  }

  private func disconnect(result: @escaping FlutterResult) {
    guard let p = connected else {
      result(true)
      return
    }
    pendingDisconnect = result
    central.cancelPeripheralConnection(p)
  }

  // MARK: - BLE command mappings
  private func getBatteryLevel(result: @escaping FlutterResult) {
    QCSDKCmdCreator.readBatterySuccess({ battery, charging in
      result([
        "level": Int(battery),
        "charging": charging
      ])
    }, failed: {
      result(FlutterError(code: "BATTERY_FAIL", message: "readBattery failed", details: nil))
    })
  }

  private func readHardwareRevision(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getDeviceSoftAndHardVersionSuccess({ _, hard in
      result(hard)
    }, fail: {
      result(FlutterError(code: "READ_HW_FAIL", message: "read hardware version failed", details: nil))
    })
  }

  private func readFirmwareRevision(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getDeviceSoftAndHardVersionSuccess({ soft, _ in
      result(soft)
    }, fail: {
      result(FlutterError(code: "READ_FW_FAIL", message: "read firmware version failed", details: nil))
    })
  }

  private func syncTimeAndGetCoreFeatures(result: @escaping FlutterResult) {
    QCSDKCmdCreator.setTime(Date(), success: { featureList in
      result(featureList)
    }, failed: {
      result(FlutterError(code: "SET_TIME_FAIL", message: "setTime failed", details: nil))
    })
  }

  private func readHrSetting(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualHeartRateStatusAndInterval(success: { enable, interval in
      result(["isEnable": enable, "interval": Int(interval)])
    }, fail: {
      result(FlutterError(code: "HR_READ_FAIL", message: "heart rate status read failed", details: nil))
    })
  }

  private func writeHrSetting(isEnable: Bool, interval: Int, result: @escaping FlutterResult) {
    QCSDKCmdCreator.setSchedualHeartRateStatus(isEnable, timeInterval: interval, success: {
      result(["isEnable": isEnable, "interval": interval])
    }, fail: {
      result(FlutterError(code: "HR_WRITE_FAIL", message: "heart rate write failed", details: nil))
    })
  }

  private func readSpo2Setting(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualBOInfoSuccess({ featureOn in
      result(["isEnable": featureOn])
    }, fail: {
      result(FlutterError(code: "SPO2_READ_FAIL", message: "spo2 read failed", details: nil))
    })
  }

  private func writeSpo2Setting(isEnable: Bool, result: @escaping FlutterResult) {
    QCSDKCmdCreator.setSchedualBOInfoOn(isEnable, success: { featureOn in
      result(["isEnable": featureOn])
    }, fail: {
      result(FlutterError(code: "SPO2_WRITE_FAIL", message: "spo2 write failed", details: nil))
    })
  }

  private func readBpSetting(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualBPInfo({ featureOn, beginTime, endTime, minuteInterval in
      let partsB = beginTime.split(separator: ":").compactMap { Int($0) }
      let partsE = endTime.split(separator: ":").compactMap { Int($0) }
      let sh = partsB.first ?? 9
      let sm = partsB.dropFirst().first ?? 0
      let eh = partsE.first ?? 21
      let em = partsE.dropFirst().first ?? 0
      result([
        "isEnable": featureOn,
        "multiple": Int(minuteInterval),
        "window": [
          "startHour": sh,
          "startMinute": sm,
          "endHour": eh,
          "endMinute": em,
        ]
      ])
    }, fail: {
      result(FlutterError(code: "BP_READ_FAIL", message: "bp read failed", details: nil))
    })
  }

  private func writeBpSetting(
    isEnable: Bool,
    startHour: Int,
    startMinute: Int,
    endHour: Int,
    endMinute: Int,
    multiple: Int,
    result: @escaping FlutterResult
  ) {
    let bStr = String(format: "%02d:%02d", startHour, startMinute)
    let eStr = String(format: "%02d:%02d", endHour, endMinute)
    QCSDKCmdCreator.setSchedualBPInfoOn(
      isEnable,
      beginTime: bStr,
      endTime: eStr,
      minuteInterval: multiple,
      success: { featureOn, begin, end, minute in
        result([
          "isEnable": featureOn,
          "multiple": Int(minute),
          "window": [
            "startHour": startHour,
            "startMinute": startMinute,
            "endHour": endHour,
            "endMinute": endMinute,
          ]
        ])
      },
      fail: {
        result(FlutterError(code: "BP_WRITE_FAIL", message: "bp write failed", details: nil))
      }
    )
  }

  private func readPressureSetting(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualStressStatus(finshed: { enable, error in
      if let err = error {
        result(FlutterError(code: "PRESS_READ_FAIL", message: err.localizedDescription, details: nil))
      } else {
        result(["isEnable": enable])
      }
    })
  }

  private func writePressureSetting(isEnable: Bool, result: @escaping FlutterResult) {
    QCSDKCmdCreator.setSchedualStressStatus(isEnable, finshed: { error in
      if let err = error {
        result(FlutterError(code: "PRESS_WRITE_FAIL", message: err.localizedDescription, details: nil))
      } else {
        result(["isEnable": isEnable])
      }
    })
  }

  private func readHrvSetting(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualHRV(finshed: { enable, error in
      if let err = error {
        result(FlutterError(code: "HRV_READ_FAIL", message: err.localizedDescription, details: nil))
      } else {
        result(["isEnable": enable])
      }
    })
  }

  private func writeHrvSetting(isEnable: Bool, result: @escaping FlutterResult) {
    QCSDKCmdCreator.setSchedualHRVStatus(isEnable, finshed: { error in
      if let err = error {
        result(FlutterError(code: "HRV_WRITE_FAIL", message: err.localizedDescription, details: nil))
      } else {
        result(["isEnable": isEnable])
      }
    })
  }

  private func syncHeartRate(nowTime: Int?, result: @escaping FlutterResult) {
    let utc = nowTime ?? Int(Date().timeIntervalSince1970)
    let targetDate = Date(timeIntervalSince1970: TimeInterval(utc))
    let startOfDay = Calendar.current.startOfDay(for: targetDate)

    QCSDKCmdCreator.getSchedualHeartRateData(with: [startOfDay], success: { models in
      guard let model = models.first else {
        result(["utcTime": utc, "heartRateArray": [], "endFlag": true])
        return
      }

      let heartRates = model.heartRates.map { $0.intValue }
      let secondInterval = Int(model.secondInterval)

      result([
        "utcTime": utc,
        "heartRateArray": heartRates,
        "interval": secondInterval,
        "endFlag": true
      ])
    }, fail: {
      result(FlutterError(code: "HR_SYNC_FAIL", message: "heart rate sync failed", details: nil))
    })
  }

  private func syncSleepNew(offset: Int, result: @escaping FlutterResult) {
    // offset: 0 today, 1 yesterday (SDK only returns recent data)
    let clamped = max(0, min(offset, 1))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

    QCSDKCmdCreator.getSleepDetailDataV2(byDay: clamped, sleepDatas: { dict in
      // dict: [dateString: [QCSleepModel]]
      guard let first = dict.first,
            let sleeps = first.value as? [QCSleepModel],
            !sleeps.isEmpty else {
        result(nil)
        return
      }

      // Sort by start time to build contiguous segments
      let sorted = sleeps.sorted { lhs, rhs in
        let l = formatter.date(from: lhs.happenDate) ?? .distantPast
        let r = formatter.date(from: rhs.happenDate) ?? .distantPast
        return l < r
      }

      var segments: [[String: Any]] = []
      var startEpoch: Int?
      var maxEndEpoch = 0

      for s in sorted {
        guard let startDate = formatter.date(from: s.happenDate) else { continue }
        let endDate = formatter.date(from: s.endTime)
          ?? startDate.addingTimeInterval(TimeInterval(max(s.total, 0) * 60))
        let duration = Int(max(0.0, endDate.timeIntervalSince(startDate)))
        if duration <= 0 { continue }

        let typeVal: Int
        switch s.type {
        case .SLEEPTYPEDEEP:
          typeVal = 3 // deep
        case .SLEEPTYPELIGHT:
          typeVal = 2 // light
        case .SLEEPTYPESOBER:
          typeVal = 5 // awake
        case .SLEEPTYPEREM:
          typeVal = 4 // rem
        default:
          typeVal = 0
        }

        let startSec = Int(startDate.timeIntervalSince1970)
        let endSec = Int(endDate.timeIntervalSince1970)

        if startEpoch == nil || startSec < startEpoch! { startEpoch = startSec }
        if endSec > maxEndEpoch { maxEndEpoch = endSec }

        segments.append([
          "d": duration,
          "t": typeVal
        ])
      }

      guard let st = startEpoch, !segments.isEmpty else {
        result(nil)
        return
      }
      let totalDuration = segments.reduce(0) { $0 + ($1["d"] as? Int ?? 0) }
      let et = max(maxEndEpoch, st + totalDuration)

      result([
        "st": st,     // epoch-sec start
        "et": et,     // epoch-sec end
        "list": segments
      ])
    }, fail: {
      result(FlutterError(code: "SLEEP_FAIL", message: "sleep read failed", details: nil))
    })
  }

  private func syncSleepDisplay(dayOffset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(dayOffset, 6))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

    QCSDKCmdCreator.getSleepDetailData(byDay: clamped, sleepDatas: { sleeps in
      if sleeps.isEmpty {
        result(nil)
        return
      }

      var list: [[String: Any]] = []
      var totalSleep = 0
      var deepSleep = 0
      var shallowSleep = 0
      var awake = 0

      var minStart: Date?
      var maxEnd: Date?

      for s in sleeps {
        let start = formatter.date(from: s.happenDate)
        let end = formatter.date(from: s.endTime)

        let startDate = start ?? Date()
        let endDate = end ?? startDate.addingTimeInterval(TimeInterval(max(s.total, 0) * 60))
        let durationMin = max(s.total, 0)

        let typeVal: Int
        switch s.type {
        case .SLEEPTYPEDEEP:
          typeVal = 1
          deepSleep += durationMin
          totalSleep += durationMin
        case .SLEEPTYPELIGHT, .SLEEPTYPEREM:
          typeVal = 2
          shallowSleep += durationMin
          totalSleep += durationMin
        case .SLEEPTYPESOBER:
          typeVal = 3
          awake += durationMin
        default:
          typeVal = 0
        }

        list.append([
          "sleepStart": Int(startDate.timeIntervalSince1970),
          "sleepEnd": Int(endDate.timeIntervalSince1970),
          "type": typeVal
        ])

        if minStart == nil || startDate < minStart! { minStart = startDate }
        if maxEnd == nil || endDate > maxEnd! { maxEnd = endDate }
      }

      let sleepTime = minStart != nil ? Int(minStart!.timeIntervalSince1970) : 0
      let wakeTime = maxEnd != nil ? Int(maxEnd!.timeIntervalSince1970) : 0

      result([
        "totalSleepDuration": totalSleep,
        "deepSleepDuration": deepSleep,
        "shallowSleepDuration": shallowSleep,
        "awakeDuration": awake,
        "sleepTime": sleepTime,
        "wakeTime": wakeTime,
        "list": list
      ])
    }, fail: {
      result(FlutterError(code: "SLEEP_DISPLAY_FAIL", message: "sleep display failed", details: nil))
    })
  }

  private func syncTodaySport(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getCurrentSportSucess({ model in
      let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())

      result([
        "daysAgo": 0,
        "year": comps.year ?? 0,
        "month": comps.month ?? 0,
        "day": comps.day ?? 0,
        "totalSteps": Int(model.totalStepCount),
        "runningSteps": Int(model.runStepCount),
        "calorie": Int(model.calories.rounded()),
        "walkDistance": Int(model.distance),
        "sportDuration": Int(model.activeTime),
        "sleepDuration": 0
      ])
    }, failed: {
      result(FlutterError(code: "SPORT_TODAY_FAIL", message: "today sport failed", details: nil))
    })
  }

  private func enableRealtimeNotifications(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    manager.currentStepInfo = { [weak self] step, calorie, distance in
      guard let self = self else { return }
      self.mainQueue.async {
        self.emit([
          "type": "rtSportSummary",
          "steps": step,
          "calorie": calorie,
          "distance": distance
        ])
      }
    }
    manager.currentBatteryInfo = { [weak self] battery, charging in
      guard let self = self else { return }
      self.mainQueue.async {
        if charging {
          self.emit([
            "type": "rtCharging",
            "isCharging": true,
            "percent": battery
          ])
        } else {
          self.emit([
            "type": "rtBattery",
            "isCharging": false,
            "percent": battery
          ])
        }
      }
    }
    realtimeStepHooked = true
    realtimeBatteryHooked = true
    result(true)
  }

  private func disableRealtimeNotifications(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    manager.currentStepInfo = { _, _, _ in }
    manager.currentBatteryInfo = { _, _ in }
    realtimeStepHooked = false
    realtimeBatteryHooked = false
    result(true)
  }

  private func syncSportDetail(dayOffset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(dayOffset, 6))
    QCSDKCmdCreator.getSportDetailData(
      byDay: clamped,
      minuteInterval: 15,
      begin: 0,
      end: 95,
      sportDatas: { sports in
        if sports.isEmpty {
          result(["details": []])
          return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var details: [[String: Any]] = []
        let calendar = Calendar.current

        for sport in sports {
          guard let date = formatter.date(from: sport.happenDate) else { continue }
          let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
          guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }
          let hour = comps.hour ?? 0
          let minute = comps.minute ?? 0
          let timeIndex = ((hour * 60) + minute) / 15
          if timeIndex < 0 || timeIndex > 95 { continue }

          let total = Int(sport.totalStepCount)
          let run = Int(sport.runStepCount)
          let walk = max(total - run, 0)
          let calorie = Int(sport.calories.rounded())
          let distance = Int(sport.distance)

          details.append([
            "year": y,
            "month": m,
            "day": d,
            "timeIndex": timeIndex,
            "calorie": calorie,
            "walkSteps": walk,
            "distance": distance,
            "runSteps": run,
          ])
        }

        result(["details": details])
      },
      fail: {
        result(FlutterError(code: "SPORT_DETAIL_FAIL", message: "sport detail failed", details: nil))
      }
    )
  }

  private func syncSedentary(offset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(offset, 6))
    QCSDKCmdCreator.getSedentaryReminder(fromDay: clamped) { dict, error in
      if let err = error {
        result(FlutterError(code: "SEDENTARY_FAIL", message: err.localizedDescription, details: nil))
        return
      }
      guard let dict = dict, let first = dict.values.first as? [QCSedentaryModel] else {
        result(nil)
        return
      }
      let list = first.map { m in
        [
          "d": Int(m.duration),
          "t": Int(m.type)
        ]
      }
      result([
        "index": clamped,
        "list": list
      ])
    }
  }

  private func syncBloodOxygen(result: @escaping FlutterResult) {
    // iOS SDK는 SpO2 일별 요청 시 malformed 응답에서 프로세스 크래시 가능 → 최소 범위만 조회
    let dayIndexes = Array(0...2)
    var entries: [[String: Any]] = []
    var lastError: NSError?

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"

    let calendar = Calendar.current

    func appendEntries(from list: [QCBloodOxygenModel]) {
      var perDay: [Date: (min: [Int], max: [Int])] = [:]

      for item in list {
        guard let date = item.date else { continue }
        let dayStart = calendar.startOfDay(for: date)
        let hour = calendar.component(.hour, from: date)

        var record = perDay[dayStart] ?? (min: Array(repeating: 0, count: 24),
                                          max: Array(repeating: 0, count: 24))

        let vMin = Int(item.minSoa2)
        let vMax = Int(item.maxSoa2)
        let v = Int(item.soa2)

        let minVal = vMin > 0 ? vMin : v
        let maxVal = vMax > 0 ? vMax : v

        if minVal > 0 {
          if record.min[hour] == 0 || minVal < record.min[hour] {
            record.min[hour] = minVal
          }
        }
        if maxVal > 0 {
          if maxVal > record.max[hour] {
            record.max[hour] = maxVal
          }
        }

        perDay[dayStart] = record
      }

      for (dayStart, arrays) in perDay {
        let dateStr = formatter.string(from: dayStart)
        let unixTime = Int(dayStart.timeIntervalSince1970)
        entries.append([
          "dateStr": dateStr,
          "minArray": arrays.min,
          "maxArray": arrays.max,
          "unix_time": unixTime,
        ])
      }
    }

    func fetchDay(at index: Int) {
      guard index < dayIndexes.count else {
        if entries.isEmpty, let err = lastError {
          result(FlutterError(code: "BLOOD_OXYGEN_FAIL", message: err.localizedDescription, details: nil))
        } else {
          result(entries)
        }
        return
      }

      let dayIndex = dayIndexes[index]
      QCSDKCmdCreator.getBloodOxygenData(byDayIndex: dayIndex) { data, error in
        if let err = error as NSError? {
          lastError = err
        } else if let list = data as? [QCBloodOxygenModel], !list.isEmpty {
          appendEntries(from: list)
        }

        // SDK BLE 응답 파싱 충돌 방지: 일별 요청을 순차 처리
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          fetchDay(at: index + 1)
        }
      }
    }

    fetchDay(at: 0)
  }

  private func routeManualMeasurement(type: String, legacyResult: @escaping FlutterResult) {
    RingMeasurementSession.shared.preemptForManualMeasurement { [weak self] in
      guard let self = self else { return }
      switch type {
      case "bloodOxygen":
        self.syncManualBloodOxygen(result: legacyResult)
      case "heartRate":
        self.syncManualHeartRate(result: legacyResult)
      case "stress":
        self.syncManualPressure(result: legacyResult)
      default:
        self.invokeFlutterResult(
          legacyResult,
          FlutterError(code: "MEASURE_INVALID_TYPE", message: "unknown type \(type)", details: nil)
        )
      }
    }
  }

  // MARK: - Manual measure helpers

  private func clearManualMeasuringHooks(_ manager: QCSDKManager) {
    manager.boMeasuring = { _ in }
    manager.hrMeasuring = { _ in }
    manager.realTimeHeartRate = { _ in }
    manager.measuringFail = { }
  }

  private func retrySetSchedualBOOff(attempt: Int = 0, completion: @escaping (Bool) -> Void) {
    QCSDKCmdCreator.setSchedualBOInfoOn(false, success: { _ in
      completion(true)
    }, fail: {
      if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualBOOff(attempt: attempt + 1, completion: completion)
        }
      } else {
        completion(false)
      }
    })
  }

  private func retrySetSchedualBOOn(attempt: Int = 0) {
    QCSDKCmdCreator.setSchedualBOInfoOn(true, success: { _ in
      print("[SPO2_MANUAL] scheduled SpO2 restored")
    }, fail: {
      if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualBOOn(attempt: attempt + 1)
        }
      } else {
        print("[SPO2_MANUAL] scheduled SpO2 restore failed")
      }
    })
  }

  private func retrySetSchedualHrOff(
    interval: Int,
    attempt: Int = 0,
    completion: @escaping (Bool) -> Void
  ) {
    QCSDKCmdCreator.setSchedualHeartRateStatus(false, timeInterval: interval, success: {
      completion(true)
    }, fail: {
      if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualHrOff(interval: interval, attempt: attempt + 1, completion: completion)
        }
      } else {
        completion(false)
      }
    })
  }

  private func retrySetSchedualHrOn(interval: Int, attempt: Int = 0) {
    QCSDKCmdCreator.setSchedualHeartRateStatus(true, timeInterval: interval, success: {
      print("[HR_MANUAL] scheduled HR restored (interval=\(interval))")
    }, fail: {
      if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualHrOn(interval: interval, attempt: attempt + 1)
        }
      } else {
        print("[HR_MANUAL] scheduled HR restore failed")
      }
    })
  }

  private func retrySetSchedualStressOff(attempt: Int = 0, completion: @escaping (Bool) -> Void) {
    QCSDKCmdCreator.setSchedualStressStatus(false) { error in
      if error == nil {
        completion(true)
      } else if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualStressOff(attempt: attempt + 1, completion: completion)
        }
      } else {
        completion(false)
      }
    }
  }

  private func retrySetSchedualHrOn(
    interval: Int,
    attempt: Int = 0,
    completion: @escaping (Bool) -> Void
  ) {
    QCSDKCmdCreator.setSchedualHeartRateStatus(true, timeInterval: interval, success: {
      completion(true)
    }, fail: {
      if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualHrOn(interval: interval, attempt: attempt + 1, completion: completion)
        }
      } else {
        completion(false)
      }
    })
  }

  /// 수동 SpO₂ — `startToMeasuring(.bloodOxygen)` 단일 경로. 스케줄 복구는 Flutter `enableRingAutoMonitoring` 에 맡긴다.
  private func syncManualBloodOxygen(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    clearManualMeasuringHooks(manager)

    let begin: () -> Void = {
      self.mainQueue.asyncAfter(deadline: .now() + 0.4) {
        self.beginManualBloodOxygenMeasuring(result: result)
      }
    }

    QCSDKCmdCreator.getSchedualBOInfoSuccess({ enabled in
      guard enabled else {
        print("[SPO2_MANUAL] scheduled SpO2 already off")
        begin()
        return
      }
      self.retrySetSchedualBOOff { paused in
        print("[SPO2_MANUAL] scheduled SpO2 pause \(paused ? "ok" : "failed")")
        begin()
      }
    }, fail: {
      print("[SPO2_MANUAL] getSchedualBOInfo failed — measure anyway")
      begin()
    })
  }

  private func beginManualBloodOxygenMeasuring(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestValue = 0
    var spo2Observer: NSObjectProtocol?
    var finishObserver: NSObjectProtocol?
    var timeout: DispatchWorkItem?

    func extractSpO2Value(_ raw: Any?) -> Int {
      if let n = raw as? NSNumber { return n.intValue }
      if let i = raw as? Int { return i }
      if let f = raw as? Float { return Int(f.rounded()) }
      if let d = raw as? Double { return Int(d.rounded()) }
      if let model = raw as? QCBloodOxygenModel {
        return Int(model.soa2.rounded())
      }
      return 0
    }

    func extractSpO2FromNotification(_ note: Notification) -> Int {
      let direct = extractSpO2Value(note.object)
      if direct > 0 { return direct }
      guard let info = note.userInfo else { return 0 }
      for key in ["spo2", "so2", "soa2", "value", "bloodOxygen"] {
        if let n = info[key] as? NSNumber { return n.intValue }
        if let i = info[key] as? Int { return i }
      }
      return 0
    }

    func cleanup() {
      timeout?.cancel()
      if let obs = spo2Observer {
        NotificationCenter.default.removeObserver(obs)
        spo2Observer = nil
      }
      if let obs = finishObserver {
        NotificationCenter.default.removeObserver(obs)
        finishObserver = nil
      }
      manager.boMeasuring = { _ in }
      manager.measuringFail = { }
    }

    func finish(_ value: Any?) {
      guard !replied else { return }
      replied = true
      cleanup()
      self.invokeFlutterResult(result, value)
    }
    func finishOk(_ value: Int) {
      guard value > 0, value <= 100 else { return }
      print("[SPO2_MANUAL] result=\(value)")
      finish(["spo2": value, "value": value])
    }

    func finishErr(_ code: String, _ message: String) {
      print("[SPO2_MANUAL] error \(code): \(message)")
      finish(FlutterError(code: code, message: message, details: nil))
    }

    timeout = DispatchWorkItem {
      if latestValue > 0 {
        finishOk(latestValue)
      } else {
        finishErr("SPO2_MANUAL_TIMEOUT", "manual SpO2 timeout")
      }
    }
    mainQueue.asyncAfter(deadline: .now() + .seconds(45), execute: timeout!)

    _ = OdmBandNotifyCenter.registerNotify()
    spo2Observer = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeSO2),
      object: nil,
      queue: .main
    ) { note in
      let v = extractSpO2FromNotification(note)
      if v > 0 && v <= 100 {
        latestValue = v
        finishOk(v)
      }
    }
    finishObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeBloodOxygenFinish),
      object: nil,
      queue: .main
    ) { note in
      let v = extractSpO2FromNotification(note)
      if v > 0 && v <= 100 {
        latestValue = v
        finishOk(v)
        return
      }
      if latestValue > 0 {
        finishOk(latestValue)
      }
    }

    manager.boMeasuring = { so2 in
      let v = Int(so2.rounded())
      guard v > 0 && v <= 100 else { return }
      print("[SPO2_MANUAL] boMeasuring=\(v)")
      latestValue = v
      self.mainQueue.async { finishOk(v) }
    }
    manager.measuringFail = {
      self.mainQueue.async {
        guard !replied else { return }
        if latestValue > 0 {
          finishOk(latestValue)
          return
        }
        finishErr("SPO2_MANUAL_FAIL", "manual SpO2 failed")
      }
    }

    manager.startToMeasuring(
      withOperateType: .bloodOxygen,
      timeout: 45,
      measuringHandle: { measuringResult in
        let v = extractSpO2Value(measuringResult)
        guard v > 0 && v <= 100 else { return }
        print("[SPO2_MANUAL] measuringHandle=\(v)")
        latestValue = v
        self.mainQueue.async { finishOk(v) }
      },
      completedHandle: { isSuccess, finalResult, error in
        self.mainQueue.async {
          guard !replied else { return }
          let v = extractSpO2Value(finalResult)
          if v > 0 && v <= 100 {
            print("[SPO2_MANUAL] completedHandle=\(v) success=\(isSuccess)")
            finishOk(v)
            return
          }
          if latestValue > 0 {
            finishOk(latestValue)
            return
          }
          if let err = error as NSError? {
            print("[SPO2_MANUAL] completed error \(err.code) \(err.localizedDescription)")
            if err.code == -3 {
              finishErr("SPO2_MANUAL_WEAR", err.localizedDescription)
            }
          }
        }
      }
    )
  }

  /// 수동 심박 — SpO₂ 와 동일하게 `startToMeasuring(.heartRate)` 단일 경로.
  private func syncManualHeartRate(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    clearManualMeasuringHooks(manager)

    var savedHrInterval = IosRingMeasurementPolicy.ringAutoHeartIntervalMinutes

    let begin: () -> Void = {
      self.mainQueue.asyncAfter(deadline: .now() + 0.4) {
        self.beginManualHeartRateMeasuring(result: result)
      }
    }

    QCSDKCmdCreator.getSchedualHeartRateStatusAndInterval(success: { enabled, interval in
      if interval > 0 {
        savedHrInterval = interval
      }
      guard enabled else {
        print("[HR_MANUAL] scheduled HR already off")
        begin()
        return
      }
      self.retrySetSchedualHrOff(interval: savedHrInterval) { paused in
        print("[HR_MANUAL] scheduled HR pause \(paused ? "ok" : "failed")")
        begin()
      }
    }, fail: {
      print("[HR_MANUAL] getSchedualHeartRate failed — measure anyway")
      begin()
    })
  }

  private func beginManualHeartRateMeasuring(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestValue = 0
    var hrObserver: NSObjectProtocol?
    var finishObserver: NSObjectProtocol?
    var timeout: DispatchWorkItem?

    func extractHrValue(_ raw: Any?) -> Int {
      if let n = raw as? NSNumber { return n.intValue }
      if let i = raw as? Int { return i }
      if let model = raw as? QCHeartRateModel {
        return Int(model.heartrate)
      }
      return 0
    }

    func extractHrFromNotification(_ note: Notification) -> Int {
      let direct = extractHrValue(note.object)
      if direct > 0 { return direct }
      guard let info = note.userInfo else { return 0 }
      for key in ["hr", "heartRate", "value"] {
        if let n = info[key] as? NSNumber { return n.intValue }
        if let i = info[key] as? Int { return i }
      }
      return 0
    }

    func cleanup() {
      timeout?.cancel()
      if let obs = hrObserver {
        NotificationCenter.default.removeObserver(obs)
        hrObserver = nil
      }
      if let obs = finishObserver {
        NotificationCenter.default.removeObserver(obs)
        finishObserver = nil
      }
      manager.hrMeasuring = { _ in }
      manager.realTimeHeartRate = { _ in }
      manager.measuringFail = { }
    }

    func finish(_ value: Any?) {
      guard !replied else { return }
      replied = true
      cleanup()
      self.invokeFlutterResult(result, value)
    }

    func finishOk(_ value: Int) {
      guard value > 0 else { return }
      print("[HR_MANUAL] result=\(value)")
      finish(["hr": value, "value": value])
    }

    func finishErr(_ code: String, _ message: String) {
      print("[HR_MANUAL] error \(code): \(message)")
      finish(FlutterError(code: code, message: message, details: nil))
    }

    timeout = DispatchWorkItem {
      if latestValue > 0 {
        finishOk(latestValue)
      } else {
        finishErr("HR_MANUAL_TIMEOUT", "manual HR timeout")
      }
    }
    mainQueue.asyncAfter(deadline: .now() + .seconds(45), execute: timeout!)

    _ = OdmBandNotifyCenter.registerNotify()
    hrObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeHeartRate),
      object: nil,
      queue: .main
    ) { note in
      let v = extractHrFromNotification(note)
      if v > 0 {
        latestValue = v
        finishOk(v)
      }
    }
    finishObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeHeartRateFinish),
      object: nil,
      queue: .main
    ) { note in
      let v = extractHrFromNotification(note)
      if v > 0 {
        latestValue = v
        finishOk(v)
        return
      }
      if latestValue > 0 {
        finishOk(latestValue)
      }
    }

    manager.hrMeasuring = { hr in
      let v = Int(hr)
      guard v > 0 else { return }
      print("[HR_MANUAL] hrMeasuring=\(v)")
      latestValue = v
      self.mainQueue.async { finishOk(v) }
    }
    manager.realTimeHeartRate = { hr in
      let v = Int(hr)
      guard v > 0 else { return }
      print("[HR_MANUAL] realTimeHeartRate=\(v)")
      latestValue = v
      self.mainQueue.async { finishOk(v) }
    }
    manager.measuringFail = {
      self.mainQueue.async {
        guard !replied else { return }
        if latestValue > 0 {
          finishOk(latestValue)
          return
        }
        finishErr("HR_MANUAL_FAIL", "manual HR failed")
      }
    }

    manager.startToMeasuring(
      withOperateType: .heartRate,
      timeout: 45,
      measuringHandle: { measuringResult in
        let v = extractHrValue(measuringResult)
        guard v > 0 else { return }
        print("[HR_MANUAL] measuringHandle=\(v)")
        latestValue = v
        self.mainQueue.async { finishOk(v) }
      },
      completedHandle: { isSuccess, finalResult, error in
        self.mainQueue.async {
          guard !replied else { return }
          let v = extractHrValue(finalResult)
          if v > 0 {
            print("[HR_MANUAL] completedHandle=\(v) success=\(isSuccess)")
            finishOk(v)
            return
          }
          if latestValue > 0 {
            finishOk(latestValue)
            return
          }
          if let err = error as NSError? {
            print("[HR_MANUAL] completed error \(err.code) \(err.localizedDescription)")
            if err.code == -3 {
              finishErr("HR_MANUAL_WEAR", err.localizedDescription)
            }
          }
        }
      }
    )
  }

  private func readLatestScheduledStressScore(completion: @escaping (Int) -> Void) {
    QCSDKCmdCreator.getSchedualStressData(withDates: [0]) { data, error in
      self.mainQueue.async {
        if let err = error {
          print("[STRESS_MANUAL] getSchedualStressData: \(err.localizedDescription)")
          completion(0)
          return
        }
        guard let list = data as? [QCStressModel],
              let model = list.first,
              let latest = model.stresses.reversed().first(where: { $0.intValue > 0 })?.intValue,
              latest > 0 else {
          completion(0)
          return
        }
        completion(latest)
      }
    }
  }

  private func retrySetSchedualHrvOff(attempt: Int = 0, completion: @escaping (Bool) -> Void) {
    QCSDKCmdCreator.setSchedualHRVStatus(false) { error in
      if error == nil {
        completion(true)
      } else if attempt < 2 {
        self.mainQueue.asyncAfter(deadline: .now() + 0.5) {
          self.retrySetSchedualHrvOff(attempt: attempt + 1, completion: completion)
        }
      } else {
        completion(false)
      }
    }
  }

  /// HR/SpO₂ 수동 직전과 같이 — 자동 스트레스·HRV 스케줄이 켜져 있으면 잠시 끈다.
  private func pauseStressPipelineForManual(completion: @escaping () -> Void) {
    let group = DispatchGroup()

    group.enter()
    QCSDKCmdCreator.getSchedualStressStatus(finshed: { enabled, _ in
      guard enabled else {
        print("[STRESS_MANUAL] scheduled stress already off")
        group.leave()
        return
      }
      self.retrySetSchedualStressOff { paused in
        print("[STRESS_MANUAL] scheduled stress pause \(paused ? "ok" : "failed")")
        group.leave()
      }
    })

    group.enter()
    QCSDKCmdCreator.getSchedualHRV(finshed: { enabled, _ in
      guard enabled else {
        print("[STRESS_MANUAL] scheduled HRV already off")
        group.leave()
        return
      }
      self.retrySetSchedualHrvOff { paused in
        print("[STRESS_MANUAL] scheduled HRV pause \(paused ? "ok" : "failed")")
        group.leave()
      }
    })

    group.notify(queue: mainQueue, execute: completion)
  }

  /// 직전 심박/SpO₂ 등 in-flight 측정 종료 — `-2`(EndOneKeyMeasuringError) 방지.
  private func stopInFlightMeasures(completion: @escaping () -> Void) {
    let manager = QCSDKManager.shareInstance()
    clearManualMeasuringHooks(manager)
    let types: [QCMeasuringType] = [.stress, .heartRate, .bloodOxygen, .HRV, .oneKeyMeasure]
    let group = DispatchGroup()
    for type in types {
      group.enter()
      var left = false
      manager.stopToMeasuring(withOperateType: type) { _, _ in
        if !left {
          left = true
          group.leave()
        }
      }
      mainQueue.asyncAfter(deadline: .now() + 1.2) {
        if !left {
          left = true
          group.leave()
        }
      }
    }
    group.notify(queue: mainQueue, execute: completion)
  }

  /// 수동 스트레스 — 심박/SpO₂ 와 동일: 스케줄 pause → in-flight stop → `startToMeasuring(.stress)`.
  private func syncManualPressure(result: @escaping FlutterResult) {
    pauseStressPipelineForManual {
      self.stopInFlightMeasures {
        self.mainQueue.asyncAfter(deadline: .now() + 0.8) {
          self.beginManualStressMeasuring(result: result)
        }
      }
    }
  }

  private func beginManualStressMeasuring(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestStress = 0
    var stressObserver: NSObjectProtocol?
    var hrvObserver: NSObjectProtocol?
    var timeout: DispatchWorkItem?

    func scoreInRange(_ v: Int) -> Int {
      (v > 0 && v <= 100) ? v : 0
    }

    func intField(_ dict: [AnyHashable: Any], _ key: String) -> Int {
      if let n = dict[key] as? NSNumber { return n.intValue }
      if let i = dict[key] as? Int { return i }
      return 0
    }

    // QC iOS 스트레스 결과는 `{ sbp: 38, dbp: 0 }` 형태로 오기도 한다.
    func extractStressScore(_ raw: Any?) -> Int {
      if let n = raw as? NSNumber {
        return scoreInRange(n.intValue)
      }
      if let i = raw as? Int {
        return scoreInRange(i)
      }
      if let dict = raw as? [AnyHashable: Any] {
        for key in ["pressure", "value", "stress"] {
          let v = scoreInRange(intField(dict, key))
          if v > 0 { return v }
        }
        let sbp = intField(dict, "sbp")
        let dbp = intField(dict, "dbp")
        if dbp <= 0 {
          let stress = scoreInRange(sbp)
          if stress > 0 { return stress }
        }
      }
      return 0
    }

    func extractFromNotification(_ note: Notification) -> Int {
      let direct = extractStressScore(note.object)
      if direct > 0 { return direct }
      guard let info = note.userInfo else { return 0 }
      let fromInfo = extractStressScore(info as [AnyHashable: Any])
      if fromInfo > 0 { return fromInfo }
      for key in ["value", "stress", "pressure", "sbp"] {
        let v = extractStressScore(info[key])
        if v > 0 { return v }
      }
      for val in info.values {
        let v = extractStressScore(val)
        if v > 0 { return v }
      }
      return 0
    }

    func cleanup() {
      timeout?.cancel()
      if let obs = stressObserver {
        NotificationCenter.default.removeObserver(obs)
        stressObserver = nil
      }
      if let obs = hrvObserver {
        NotificationCenter.default.removeObserver(obs)
        hrvObserver = nil
      }
      manager.measuringFail = { }
    }

    func finish(_ value: Any?) {
      guard !replied else { return }
      replied = true
      cleanup()
      manager.stopToMeasuring(withOperateType: .stress) { _, _ in }
      self.invokeFlutterResult(result, value)
    }

    func finishOk(_ value: Int) {
      guard value > 0 else { return }
      print("[STRESS_MANUAL] result=\(value)")
      finish(["pressure": value, "value": value])
    }

    func finishErr(_ code: String, _ message: String) {
      print("[STRESS_MANUAL] error \(code): \(message)")
      finish(FlutterError(code: code, message: message, details: nil))
    }

    timeout = DispatchWorkItem {
      if latestStress > 0 {
        finishOk(latestStress)
      } else {
        finishErr("PRESSURE_MANUAL_TIMEOUT", "manual stress timeout")
      }
    }
    mainQueue.asyncAfter(deadline: .now() + .seconds(90), execute: timeout!)

    _ = OdmBandNotifyCenter.registerNotify()
    stressObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeStress),
      object: nil,
      queue: .main
    ) { note in
      let v = extractFromNotification(note)
      if v > 0 {
        print("[STRESS_MANUAL] stress notification=\(v)")
        latestStress = v
        finishOk(v)
      }
    }
    hrvObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeHRV),
      object: nil,
      queue: .main
    ) { note in
      let v = extractFromNotification(note)
      if v > 0 {
        print("[STRESS_MANUAL] stress via hrv notification=\(v)")
        latestStress = v
        finishOk(v)
      }
    }

    manager.measuringFail = {
      self.mainQueue.async {
        guard !replied else { return }
        if latestStress > 0 {
          finishOk(latestStress)
          return
        }
        finishErr("PRESSURE_MANUAL_FAIL", "manual stress failed")
      }
    }

    var startAttempts = 0

    func startStressMeasure() {
      startAttempts += 1
      print("[STRESS_MANUAL] startToMeasuring stress (attempt \(startAttempts))")
      manager.startToMeasuring(
        withOperateType: .stress,
        timeout: 60,
        measuringHandle: { measuringResult in
          let v = extractStressScore(measuringResult)
          guard v > 0 else { return }
          print("[STRESS_MANUAL] stress measuringHandle=\(v)")
          latestStress = v
          self.mainQueue.async { finishOk(v) }
        },
        completedHandle: { isSuccess, finalResult, error in
          self.mainQueue.async {
            guard !replied else { return }
            let v = extractStressScore(finalResult)
            if v > 0 {
              print("[STRESS_MANUAL] stress completedHandle=\(v) success=\(isSuccess)")
              finishOk(v)
              return
            }
            if latestStress > 0 {
              finishOk(latestStress)
              return
            }
            if let err = error as NSError? {
              print("[STRESS_MANUAL] stress completed error \(err.code) \(err.localizedDescription)")
              if err.code == -3 {
                finishErr("PRESSURE_MANUAL_WEAR", err.localizedDescription)
                return
              }
              if err.code == -1, startAttempts < 2 {
                print("[STRESS_MANUAL] start fail -1 — retry after 1.5s")
                self.mainQueue.asyncAfter(deadline: .now() + 1.5) {
                  startStressMeasure()
                }
                return
              }
              if err.code == -1 {
                finishErr("PRESSURE_MANUAL_FAIL", "stress measure start failed")
                return
              }
              if err.code == -2 {
                print("[STRESS_MANUAL] end cmd -2 — keep waiting for stress value")
                return
              }
            }
            print("[STRESS_MANUAL] stress completed success=\(isSuccess) raw=\(String(describing: finalResult))")
          }
        }
      )
    }

    startStressMeasure()
  }

  private func executeManualMeasurement(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let type = (call.arguments as? [String: Any])?["type"] as? String ?? ""
    routeManualMeasurement(type: type, legacyResult: result)
  }

  private func syncPressure(offset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(offset, 6))
    QCSDKCmdCreator.getSchedualStressData(withDates: [NSNumber(value: clamped)]) { data, error in
      if error != nil {
        result(nil)
        return
      }
      guard let list = data as? [QCStressModel], let model = list.first else {
        result(nil)
        return
      }

      let intervalSec = Int(model.secondInterval)
      let rangeMin = max(intervalSec / 60, 1)
      let array = model.stresses.map { $0.intValue }

      let now = Date()
      let comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
      let today: [String: Any] = [
        "year": comps.year ?? 0,
        "month": comps.month ?? 0,
        "day": comps.day ?? 0,
      ]

      result([
        "range": rangeMin,
        "array": array,
        "today": today,
      ])
    }
  }

  private func syncAutoBp(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualBPHistoryData(success: { data in
      if data.isEmpty {
        result(FlutterError(code: "BP_AUTO_EMPTY", message: "no bp history", details: nil))
        return
      }
      let calendar = Calendar.current
      let firstDate = data.first?.date ?? Date()
      let comps = calendar.dateComponents([.year, .month, .day], from: firstDate)
      let dayStart = calendar.startOfDay(for: firstDate)

      let values = data.compactMap { item -> [String: Any]? in
        guard let date = item.date else { return nil }
        let minute = Int(date.timeIntervalSince(dayStart) / 60.0)
        return [
          "timeMinute": minute,
          "sbp": Int(item.systolicPressure),
          "dbp": Int(item.diastolicPressure)
        ]
      }

      result([
        "year": comps.year ?? 0,
        "month": comps.month ?? 0,
        "day": comps.day ?? 0,
        "timeDelay": 0,
        "bpValues": values
      ])
    }, fail: {
      result(FlutterError(code: "BP_AUTO_FAIL", message: "bp history failed", details: nil))
    })
  }

  private func syncManualBp(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    let timeout = DispatchWorkItem {
      manager.bpMeasuring = { _, _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "BP_MANUAL_TIMEOUT", message: "manual BP timeout", details: nil))
    }
    mainQueue.asyncAfter(deadline: .now() + .seconds(45), execute: timeout)

    manager.bpMeasuring = { sbp, dbp in
      timeout.cancel()
      manager.bpMeasuring = { _, _ in }
      manager.measuringFail = { }
      result([
        "sbp": Int(sbp),
        "dbp": Int(dbp)
      ])
    }
    manager.measuringFail = {
      timeout.cancel()
      manager.bpMeasuring = { _, _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "BP_MANUAL_FAIL", message: "manual BP failed", details: nil))
    }

    QCSDKCmdCreator.startBloodPressureMeasuringSuccess(nil, fail: {
      timeout.cancel()
      manager.bpMeasuring = { _, _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "BP_MANUAL_FAIL", message: "start BP measuring failed", details: nil))
    })
  }

  private func syncHrv(offset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(offset, 6))
    QCSDKCmdCreator.getSchedualHRVData(withDates: [NSNumber(value: clamped)]) { data, error in
      if let err = error {
        result(FlutterError(code: "HRV_FAIL", message: err.localizedDescription, details: nil))
        return
      }
      guard let list = data as? [QCHRVModel], let model = list.first else {
        result(nil)
        return
      }
      let intervalSec = Int(model.secondInterval)
      let rangeMin = max(intervalSec / 60, 1)
      let array = model.hrv.map { $0.intValue }

      let now = Date()
      let comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
      let today: [String: Any] = [
        "year": comps.year ?? 0,
        "month": comps.month ?? 0,
        "day": comps.day ?? 0,
      ]

      result([
        "range": rangeMin,
        "array": array,
        "today": today,
      ])
    }
  }

  private func syncManualHrv(result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualHRVData(withDates: [0]) { data, error in
      if let err = error {
        result(FlutterError(code: "HRV_MANUAL_FAIL", message: err.localizedDescription, details: nil))
        return
      }
      guard let list = data as? [QCHRVModel], let model = list.first else {
        result(FlutterError(code: "HRV_MANUAL_EMPTY", message: "no hrv data", details: nil))
        return
      }
      let latest = model.hrv.reversed().first { $0.intValue > 0 }?.intValue ?? 0
      if latest <= 0 {
        result(FlutterError(code: "HRV_MANUAL_EMPTY", message: "no hrv value", details: nil))
        return
      }
      result([
        "hrv": latest,
        "value": latest
      ])
    }
  }

  private func registerTempCallback(result: @escaping FlutterResult) {
    result(true)
  }

  private func syncAutoTemperature(days: Int, result: @escaping FlutterResult) {
    let clamped = max(1, min(days, 7))
    let group = DispatchGroup()
    var temps: [[String: Any]] = []
    var lastError: NSError?

    for dayIndex in 0..<clamped {
      group.enter()
      QCSDKCmdCreator.getSchedualTemperatureData(byDayIndex: dayIndex) { list, error in
        defer { group.leave() }
        if let err = error as NSError? {
          lastError = err
          return
        }
        guard let list = list as? [QCTemperatureModel] else { return }
        for item in list {
          temps.append([
            "temperature": Double(item.temperature),
            "timestamp": Int(item.time.timeIntervalSince1970 * 1000.0)
          ])
        }
      }
    }

    group.notify(queue: .main) {
      if temps.isEmpty, let err = lastError {
        result(FlutterError(code: "TEMP_FAIL", message: err.localizedDescription, details: nil))
        return
      }
      result([
        "temperatures": temps,
        "source": "auto"
      ])
    }
  }

  private func syncManualTemperature(offset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(offset, 6))
    QCSDKCmdCreator.getManualTemperatureData(byDayIndex: clamped) { list, error in
      if let err = error {
        result(FlutterError(code: "TEMP_ONCE_FAIL", message: err.localizedDescription, details: nil))
        return
      }
      guard let list = list as? [QCTemperatureModel], !list.isEmpty else {
        result(FlutterError(code: "TEMP_EMPTY", message: "no manual temperature", details: nil))
        return
      }
      let temps = list.map { item in
        [
          "temperature": Double(item.temperature),
          "timestamp": Int(item.time.timeIntervalSince1970 * 1000.0)
        ]
      }
      result([
        "temperatures": temps,
        "source": "manual"
      ])
    }
  }
}

// MARK: - StreamHandler
extension IosBleBridge: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // Helper to emit to stream
  private func emit(_ map: [String: Any]) {
    eventSink?(map)
  }
}

// MARK: - CBCentralManagerDelegate
extension IosBleBridge: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      resumeKeepaliveIfNeeded()
    }
  }

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      for peripheral in restored {
        peripherals[peripheral.identifier] = peripheral
        if peripheral.state == .connected {
          connected = peripheral
          peripheral.delegate = self
          QCSDKManager.shareInstance().add(peripheral) { _ in }
        }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.resumeKeepaliveIfNeeded()
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String: Any], rssi RSSI: NSNumber) {
    // 이름 prefix 필터
    if let prefix = scanPrefix, let name = peripheral.name?.lowercased() {
      if !name.hasPrefix(prefix.lowercased()) { return }
    }
    peripherals[peripheral.identifier] = peripheral

    emit([
      "type": "scanResult",
      "address": peripheral.identifier.uuidString, // uuidString을 address로 사용
      "name": peripheral.name ?? ""
    ])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil
    // picnique_ring과 동일: SDK add 후 connected 통지. setTime은 Flutter에서 1회만.
    QCSDKManager.shareInstance().add(peripheral) { [weak self] _ in
      guard let self = self else { return }
      self.finishPendingConnect()
    }
  }

  private func finishPendingConnect() {
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil
    pendingFreshReconnectPeripheral = nil
    keepaliveConnectInFlight = false
    RingMeasurementSession.shared.resetToIdle()
    if let peripheral = connected {
      emit([
        "type": "connected",
        "address": peripheral.identifier.uuidString,
        "name": peripheral.name ?? ""
      ])
    }
    pendingConnect?(true)
    pendingConnect = nil
    keepaliveConnectCompletion?(true)
    keepaliveConnectCompletion = nil
    if IosRingBackgroundPrefs.isEnabled {
      collectHealthRecordsIfConnected(force: true)
      checkBatteryStatusIfConnected(force: true)
    }
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil
    keepaliveConnectInFlight = false
    pendingConnect?(FlutterError(code: "CONNECT_FAIL", message: error?.localizedDescription, details: nil))
    pendingConnect = nil
    keepaliveConnectCompletion?(false)
    keepaliveConnectCompletion = nil
    scheduleKeepaliveReconnectAfterDisconnect()
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    QCSDKManager.shareInstance().remove(peripheral)

    if let fresh = pendingFreshReconnectPeripheral,
       fresh.identifier == peripheral.identifier {
      connected = fresh
      fresh.delegate = self
      central.connect(fresh, options: nil)
      return
    }

    connected = nil
    RingMeasurementSession.shared.resetToIdle()

    if let pending = pendingDisconnect {
      pending(true)
      pendingDisconnect = nil
      return
    }
    emit([
      "type": "disconnected",
      "address": peripheral.identifier.uuidString,
      "error": error?.localizedDescription ?? ""
    ])
    scheduleKeepaliveReconnectAfterDisconnect()
  }
}

// MARK: - CBPeripheralDelegate
extension IosBleBridge: CBPeripheralDelegate {
  // 현재는 별도 서비스 탐색 없이 QCSDKManager가 처리
}

extension IosBleBridge: RingMeasurementSessionDelegate {
  func measurementSessionPerformCollect(completion: @escaping () -> Void) {
    collectPendingSamples(done: completion)
  }

  func measurementSessionIsConnected() -> Bool {
    connected?.state == .connected
  }

  func measurementSessionNotifyHealthDataReady() {
    emitHealthDataReady()
  }
}
