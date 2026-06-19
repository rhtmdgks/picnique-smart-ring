import Foundation
import CoreBluetooth
import Flutter
import QCBandSDK

// iOS counterpart of android BleBridge focused on scan/connect + touch counter.
final class IosBleBridge: NSObject {
  private enum ScanState {
    case idle, scanning
  }

  private let methodChannelName = "com.example.picnique_ring/ble"
  private let eventChannelName = "com.example.picnique_ring/ble_events"
  private let fgChannelName = "com.example.picnique_ring/foreground_service_channel"

  private var methodChannel: FlutterMethodChannel!
  private var eventChannel: FlutterEventChannel!
  private var fgChannel: FlutterMethodChannel!

  private var eventSink: FlutterEventSink?

  private var _central: CBCentralManager?

  private var central: CBCentralManager {
    if let c = _central { return c }
    let c = CBCentralManager(delegate: self, queue: nil)
    _central = c
    return c
  }

  private var peripherals: [UUID: CBPeripheral] = [:]
  private var connected: CBPeripheral?
  private var scanState: ScanState = .idle
  private var scanPrefix: String?
  private var pendingConnect: FlutterResult?
  private var pendingDisconnect: FlutterResult?
  private var connectTimeoutWork: DispatchWorkItem?

  private var touchCount: Int = 0
  private var touchObserver: NSObjectProtocol?
  private var realtimeStepHooked = false
  private let mainQueue = DispatchQueue.main

  init(messenger: FlutterBinaryMessenger) {
    super.init()

    methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler(handle)

    eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    eventChannel.setStreamHandler(self)

    fgChannel = FlutterMethodChannel(name: fgChannelName, binaryMessenger: messenger)
    fgChannel.setMethodCallHandler(handleForeground)
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
    case "disconnect":
      disconnect(result: result)
    case "getRingTouchCount":
      result(touchCount)
    case "enableSimpleTouchLogging":
      enableSimpleTouchLogging(result: result)
    case "disableSimpleTouchLogging":
      disableSimpleTouchLogging(result: result)
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
      let interval = (call.arguments as? [String: Any])?["interval"] as? Int ?? 30
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
    // iOS에는 별도 포그라운드 서비스가 없으므로 성공만 반환
    switch call.method {
    case "startService", "stopService":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
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
    guard let addr = deviceAddress, let uuid = UUID(uuidString: addr) else {
      result(FlutterError(code: "BAD_ARGS", message: "deviceAddress(uuidString) required", details: nil))
      return
    }

    let peripheral: CBPeripheral
    if let cached = peripherals[uuid] {
      peripheral = cached
    } else if let retrieved = central.retrievePeripherals(withIdentifiers: [uuid]).first {
      peripheral = retrieved
      peripherals[uuid] = retrieved
    } else {
      result(FlutterError(code: "NOT_FOUND", message: "Peripheral not found for \(addr)", details: nil))
      return
    }

    // 스캔 중 연결 시 CoreBluetooth/SDK 충돌 방지
    if scanState == .scanning {
      central.stopScan()
      scanState = .idle
    }

    connected = peripheral
    peripheral.delegate = self
    pendingConnect = result
    central.connect(peripheral, options: nil)

    // 연결 콜백이 끝내 오지 않는 경우를 대비한 워치독(60s)
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
    QCSDKCmdCreator.readBatterySuccess({ battery, _ in
      result(Int(battery))
    }, failed: {
      result(FlutterError(code: "BATTERY_FAIL", message: "readBattery failed", details: nil))
    })
  }

  private func enableSimpleTouchLogging(result: @escaping FlutterResult) {
    touchCount = 0
    if touchObserver == nil {
      _ = OdmBandNotifyCenter.registerNotify()
      touchObserver = NotificationCenter.default.addObserver(
        forName: .OdmBandTakePicture,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.touchCount += 1
      }
    }

    let touchType = QCTouchGestureControlType(rawValue: 3) ?? QCTouchGestureControlType(rawValue: 0)!
    QCSDKCmdCreator.setTouch(touchType, strength: 1, finshed: { error in
      if let err = error {
        result(FlutterError(code: "TOUCH_LOG_FAIL", message: err.localizedDescription, details: nil))
      } else {
        result(true)
      }
    })
  }

  private func disableSimpleTouchLogging(result: @escaping FlutterResult) {
    if let obs = touchObserver {
      NotificationCenter.default.removeObserver(obs)
      touchObserver = nil
    }
    let offType = QCTouchGestureControlType(rawValue: 0) ?? QCTouchGestureControlType(rawValue: 0)!
    QCSDKCmdCreator.setTouch(offType, strength: 1, finshed: { error in
      if let err = error {
        result(FlutterError(code: "TOUCH_LOG_FAIL", message: err.localizedDescription, details: nil))
      } else {
        result(true)
      }
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
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

    QCSDKCmdCreator.getOneDaySport(by: 0, success: { model in
      let date = formatter.date(from: model.happenDate) ?? Date()
      let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)

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
    }, fail: {
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
    realtimeStepHooked = true
    result(true)
  }

  private func disableRealtimeNotifications(result: @escaping FlutterResult) {
    QCSDKManager.shareInstance().currentStepInfo = { _, _, _ in }
    realtimeStepHooked = false
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

  private func syncManualBloodOxygen(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    let timeout = DispatchWorkItem {
      manager.boMeasuring = { _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "SPO2_MANUAL_TIMEOUT", message: "manual SpO2 timeout", details: nil))
    }
    mainQueue.asyncAfter(deadline: .now() + .seconds(45), execute: timeout)

    manager.boMeasuring = { so2 in
      timeout.cancel()
      manager.boMeasuring = { _ in }
      manager.measuringFail = { }
      result([
        "spo2": Int(so2),
        "value": Int(so2)
      ])
    }
    manager.measuringFail = {
      timeout.cancel()
      manager.boMeasuring = { _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "SPO2_MANUAL_FAIL", message: "manual SpO2 failed", details: nil))
    }

    QCSDKCmdCreator.startBloodOxygenMeasuring(success: nil, fail: {
      timeout.cancel()
      manager.boMeasuring = { _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "SPO2_MANUAL_FAIL", message: "start SpO2 measuring failed", details: nil))
    })
  }

  private func syncPressure(offset: Int, result: @escaping FlutterResult) {
    let clamped = max(0, min(offset, 6))
    QCSDKCmdCreator.getSchedualStressData(withDates: [NSNumber(value: clamped)]) { data, error in
      if let err = error {
        result(FlutterError(code: "PRESSURE_FAIL", message: err.localizedDescription, details: nil))
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

  private func syncManualPressure(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestValue = 0

    func extractStress(_ value: Any?) -> Int {
      if let n = value as? NSNumber { return n.intValue }
      if let i = value as? Int { return i }
      if let dict = value as? [AnyHashable: Any] {
        for key in ["pressure", "value", "stress"] {
          if let n = dict[key] as? NSNumber { return n.intValue }
          if let i = dict[key] as? Int { return i }
        }
      }
      return 0
    }

    func finishOk(_ value: Int) {
      guard !replied else { return }
      replied = true
      timeoutWork?.cancel()
      result(["pressure": value, "value": value])
    }

    func finishErr(_ code: String, _ message: String) {
      guard !replied else { return }
      replied = true
      timeoutWork?.cancel()
      result(FlutterError(code: code, message: message, details: nil))
    }

    var timeoutWork: DispatchWorkItem?
    let work = DispatchWorkItem {
      if latestValue > 0 {
        finishOk(latestValue)
      } else {
        finishErr("PRESSURE_MANUAL_TIMEOUT", "manual stress timeout")
      }
    }
    timeoutWork = work
    mainQueue.asyncAfter(deadline: .now() + 45, execute: work)

    // Android manualModePressure와 동일: 링에서 실시간 스트레스 측정
    manager.startToMeasuring(
      withOperateType: .stress,
      timeout: 45,
      measuringHandle: { measuringResult in
        let v = extractStress(measuringResult)
        if v > 0 { latestValue = v }
      },
      completedHandle: { isSuccess, finalResult, error in
        let finalValue = extractStress(finalResult)
        if finalValue > 0 {
          finishOk(finalValue)
          return
        }
        if latestValue > 0 {
          finishOk(latestValue)
          return
        }
        if let err = error {
          finishErr("PRESSURE_MANUAL_FAIL", err.localizedDescription)
          return
        }
        if !isSuccess {
          finishErr("PRESSURE_MANUAL_FAIL", "stress measurement failed")
          return
        }
        finishErr("PRESSURE_MANUAL_EMPTY", "no stress data")
      }
    )
  }

  private func syncManualHeartRate(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    let timeout = DispatchWorkItem {
      manager.hrMeasuring = { _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "HR_MANUAL_TIMEOUT", message: "manual HR timeout", details: nil))
    }
    mainQueue.asyncAfter(deadline: .now() + .seconds(45), execute: timeout)

    manager.hrMeasuring = { hr in
      timeout.cancel()
      manager.hrMeasuring = { _ in }
      manager.measuringFail = { }
      result([
        "hr": Int(hr),
        "value": Int(hr)
      ])
    }
    manager.measuringFail = {
      timeout.cancel()
      manager.hrMeasuring = { _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "HR_MANUAL_FAIL", message: "manual HR failed", details: nil))
    }

    QCSDKCmdCreator.startHeartRateMeasuring(success: nil, fail: {
      timeout.cancel()
      manager.hrMeasuring = { _ in }
      manager.measuringFail = { }
      result(FlutterError(code: "HR_MANUAL_FAIL", message: "start HR measuring failed", details: nil))
    })
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
    // No-op; UI에서 Bluetooth 상태를 따로 묻지는 않음
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
    // SDK에 퍼리퍼럴 등록 → setTime 후 Flutter에 연결 완료 통지
    QCSDKManager.shareInstance().add(peripheral) { [weak self] _ in
      guard let self = self else { return }
      QCSDKCmdCreator.setTime(Date(), success: { _ in
        self.finishPendingConnect()
      }, failed: {
        // setTime 실패해도 연결 자체는 유지
        self.finishPendingConnect()
      })
    }
  }

  private func finishPendingConnect() {
    pendingConnect?(true)
    pendingConnect = nil
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil
    pendingConnect?(FlutterError(code: "CONNECT_FAIL", message: error?.localizedDescription, details: nil))
    pendingConnect = nil
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    QCSDKManager.shareInstance().remove(peripheral)
    connected = nil

    if let pending = pendingDisconnect {
      pending(true)
      pendingDisconnect = nil
      return
    }
    // 의도치 않은 끊김도 이벤트로 노출 가능
    emit([
      "type": "disconnected",
      "address": peripheral.identifier.uuidString,
      "error": error?.localizedDescription ?? ""
    ])
  }
}

// MARK: - CBPeripheralDelegate
extension IosBleBridge: CBPeripheralDelegate {
  // 현재는 별도 서비스 탐색 없이 QCSDKManager가 처리
}
