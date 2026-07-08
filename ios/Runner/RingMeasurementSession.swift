import Foundation
import Flutter
import QCBandSDK

enum RingManualMeasureType: String {
  case heartRate
  case bloodOxygen
  case stress
}

enum RingSessionState {
  case idle
  case manual(RingManualMeasureType)
  case autoCollect
  case configure
}

protocol RingMeasurementSessionDelegate: AnyObject {
  func measurementSessionPerformCollect(completion: @escaping () -> Void)
  func measurementSessionIsConnected() -> Bool
  func measurementSessionNotifyHealthDataReady()
}

/// QC/Oudmon SDK 싱글톤 BLE 작업을 직렬화한다 (수동 측정 · 자동 수집 · 설정).
final class RingMeasurementSession {
  static let shared = RingMeasurementSession()

  weak var delegate: RingMeasurementSessionDelegate?

  private let serialQueue = DispatchQueue(label: "kr.picnique.ring.measurement.session")
  private let mainQueue = DispatchQueue.main
  private var state: RingSessionState = .idle
  private var pendingCatchUpCollect = false

  var isBusy: Bool {
    serialQueue.sync {
      switch state {
      case .idle: return false
      default: return true
      }
    }
  }

  private init() {}

  // MARK: - Public API

  func executeManual(type: RingManualMeasureType, result: @escaping FlutterResult) {
    var sessionReplied = false
    var sessionWatchdog: DispatchWorkItem?

    let safeResult: FlutterResult = { [weak self] value in
      guard !sessionReplied else { return }
      sessionReplied = true
      sessionWatchdog?.cancel()
      self?.finishResult(result, value)
    }

    let watchdog = DispatchWorkItem { [weak self] in
      guard !sessionReplied else { return }
      sessionReplied = true
      self?.abortManualAndReset()
      self?.finishResult(
        result,
        FlutterError(
          code: "MEASURE_SESSION_TIMEOUT",
          message: "manual measurement session timeout",
          details: nil
        )
      )
    }
    sessionWatchdog = watchdog
    mainQueue.asyncAfter(deadline: .now() + 90, execute: watchdog)

    serialQueue.async { [weak self] in
      guard let self = self else { return }
      if case .idle = self.state {
        self.state = .manual(type)
        self.mainQueue.async { [weak self] in
          guard let self = self else { return }
          let run = { self.runManual(type: type, result: safeResult) }
          switch type {
          case .bloodOxygen:
            self.prepareForSpO2Manual(completion: run)
          default:
            self.prepareRing(completion: run)
          }
        }
      } else {
        sessionWatchdog?.cancel()
        sessionReplied = true
        self.finishResult(
          result,
          FlutterError(code: "SESSION_BUSY", message: "measurement session busy", details: nil)
        )
      }
    }
  }

  func collectHealthIfIdle(force: Bool, completion: @escaping (Bool) -> Void) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        completion(false)
        return
      }
      guard case .idle = self.state else {
        self.pendingCatchUpCollect = true
        completion(false)
        return
      }
      guard self.delegate?.measurementSessionIsConnected() == true else {
        completion(false)
        return
      }
      if !force {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        if nowMs - IosRingCollectionWatermark.lastCollectMs()
            < IosRingMeasurementPolicy.minCollectGapMs {
          completion(false)
          return
        }
      }
      self.state = .autoCollect
      self.mainQueue.async {
        self.delegate?.measurementSessionPerformCollect { [weak self] in
          guard let self = self else {
            completion(false)
            return
          }
          IosRingCollectionWatermark.markCollected()
          self.serialQueue.async {
            self.state = .idle
            self.mainQueue.async {
              self.delegate?.measurementSessionNotifyHealthDataReady()
              completion(true)
              self.scheduleCatchUpIfNeeded()
            }
          }
        }
      }
    }
  }

  func runConfigureWork(_ work: @escaping (@escaping () -> Void) -> Void) {
    serialQueue.async { [weak self] in
      guard let self = self else { return }
      guard case .idle = self.state else {
        return
      }
      self.state = .configure
      work { [weak self] in
        self?.serialQueue.async {
          self?.state = .idle
          self?.scheduleCatchUpIfNeeded()
        }
      }
    }
  }

  func preemptForManualMeasurement(completion: @escaping () -> Void) {
    serialQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .idle
      self.pendingCatchUpCollect = false
      self.mainQueue.async {
        let manager = QCSDKManager.shareInstance()
        self.clearManualMeasuringHooks(manager)
        let types: [QCMeasuringType] = [.stress, .heartRate, .bloodOxygen, .oneKeyMeasure]
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
          self.mainQueue.asyncAfter(deadline: .now() + 1.5) {
            if !left {
              left = true
              group.leave()
            }
          }
        }
        group.notify(queue: self.mainQueue) {
          self.mainQueue.asyncAfter(deadline: .now() + 0.3, execute: completion)
        }
      }
    }
  }

  func resetToIdle() {
    serialQueue.async { [weak self] in
      self?.state = .idle
    }
  }

  /// Flutter 타임아웃·취소 시 세션·SDK 훅 정리.
  ///
  /// [completion]은 측정 엔진 stop 이 실제 완료(또는 2초 타임아웃)된 뒤
  /// main queue 에서 호출된다 — 선점 직후 수동 측정이 엔진 충돌 없이
  /// 시작할 수 있는 시점.
  func abortManualAndReset(completion: (() -> Void)? = nil) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { completion?() }
        return
      }
      self.state = .idle
      self.mainQueue.async {
        let manager = QCSDKManager.shareInstance()
        self.clearManualMeasuringHooks(manager)
        let types: [QCMeasuringType] = [.stress, .heartRate, .bloodOxygen, .oneKeyMeasure]
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
          self.mainQueue.asyncAfter(deadline: .now() + 2) {
            if !left {
              left = true
              group.leave()
            }
          }
        }
        group.notify(queue: self.mainQueue) {
          completion?()
        }
      }
    }
  }

  // MARK: - Prepare / cleanup

  private func prepareRing(completion: @escaping () -> Void) {
    var finished = false
    let finishOnce: () -> Void = {
      guard !finished else { return }
      finished = true
      completion()
    }

    let manager = QCSDKManager.shareInstance()
    clearManualMeasuringHooks(manager)

    let types: [QCMeasuringType] = [.stress, .heartRate, .bloodOxygen, .oneKeyMeasure]
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
      mainQueue.asyncAfter(deadline: .now() + 2) {
        if !left {
          left = true
          group.leave()
        }
      }
    }
    group.notify(queue: mainQueue) {
      self.mainQueue.asyncAfter(deadline: .now() + 0.5, execute: finishOnce)
    }
    mainQueue.asyncAfter(deadline: .now() + 5, execute: finishOnce)
  }

  /// SpO₂는 `startBloodOxygenMeasuring` 전용 API — stop/endBloodOxygen 호출 시 시작이 실패할 수 있다.
  private func prepareForSpO2Manual(completion: @escaping () -> Void) {
    var finished = false
    let finishOnce: () -> Void = {
      guard !finished else { return }
      finished = true
      completion()
    }

    let manager = QCSDKManager.shareInstance()
    clearManualMeasuringHooks(manager)

    let types: [QCMeasuringType] = [.stress, .heartRate, .oneKeyMeasure]
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
      mainQueue.asyncAfter(deadline: .now() + 1.5) {
        if !left {
          left = true
          group.leave()
        }
      }
    }
    group.notify(queue: mainQueue) {
      self.mainQueue.asyncAfter(deadline: .now() + 0.3, execute: finishOnce)
    }
    mainQueue.asyncAfter(deadline: .now() + 3, execute: finishOnce)
  }

  private func clearManualMeasuringHooks(_ manager: QCSDKManager) {
    manager.hrMeasuring = { _ in }
    manager.boMeasuring = { _ in }
    manager.bpMeasuring = { _, _ in }
    manager.measuringFail = { }
  }

  private func finishManualTransition() {
    serialQueue.async { [weak self] in
      self?.state = .idle
      self?.scheduleCatchUpIfNeeded()
    }
  }

  private func scheduleCatchUpIfNeeded() {
    serialQueue.async { [weak self] in
      guard let self = self, self.pendingCatchUpCollect else { return }
      guard case .idle = self.state else { return }
      self.pendingCatchUpCollect = false
      self.collectHealthIfIdle(force: true) { _ in }
    }
  }

  private func finishResult(_ result: @escaping FlutterResult, _ value: Any?) {
    if Thread.isMainThread {
      result(value)
    } else {
      mainQueue.async { result(value) }
    }
  }

  // MARK: - Manual runners

  private func runManual(type: RingManualMeasureType, result: @escaping FlutterResult) {
    switch type {
    case .heartRate:
      runHeartRate(result: result)
    case .bloodOxygen:
      runBloodOxygen(result: result)
    case .stress:
      runStress(result: result)
    }
  }

  private func runHeartRate(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestValue = 0
    var hardTimeout: DispatchWorkItem?

    func finishOk(_ value: Int) {
      guard !replied, value > 0 else { return }
      replied = true
      hardTimeout?.cancel()
      clearManualMeasuringHooks(manager)
      finishResult(result, ["hr": value, "value": value])
      finishManualTransition()
    }

    func finishErr(_ code: String, _ message: String) {
      guard !replied else { return }
      replied = true
      hardTimeout?.cancel()
      clearManualMeasuringHooks(manager)
      finishResult(result, FlutterError(code: code, message: message, details: nil))
      finishManualTransition()
    }

    let timeoutWork = DispatchWorkItem {
      if latestValue > 0 {
        finishOk(latestValue)
      } else {
        finishErr("HR_MANUAL_TIMEOUT", "manual HR timeout")
      }
    }
    hardTimeout = timeoutWork
    mainQueue.asyncAfter(deadline: .now() + 50, execute: timeoutWork)

    manager.hrMeasuring = { hr in
      let v = Int(hr)
      if v > 0 { latestValue = v }
      self.mainQueue.async { finishOk(v) }
    }
    manager.measuringFail = {
      self.mainQueue.async {
        if latestValue > 0 {
          finishOk(latestValue)
        } else {
          finishErr("HR_MANUAL_FAIL", "manual HR measuringFail")
        }
      }
    }

    QCSDKCmdCreator.startHeartRateMeasuring(success: nil, fail: {
      self.mainQueue.async {
        finishErr("HR_MANUAL_START_FAIL", "start HR measuring failed")
      }
    })
  }

  private func runBloodOxygen(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestValue = 0
    var hardTimeout: DispatchWorkItem?
    var spo2Observer: NSObjectProtocol?
    var finishObserver: NSObjectProtocol?
    let startedAt = Date()
    let minMeasureSec: TimeInterval = 12

    func extractFromNotification(_ note: Notification) -> Int {
      if let n = note.object as? NSNumber { return n.intValue }
      if let i = note.object as? Int { return i }
      if let f = note.object as? Float { return Int(f.rounded()) }
      if let d = note.object as? Double { return Int(d.rounded()) }
      if let model = note.object as? QCBloodOxygenModel {
        return Int(model.soa2.rounded())
      }
      guard let info = note.userInfo else { return 0 }
      for key in ["spo2", "so2", "soa2", "value", "bloodOxygen"] {
        if let n = info[key] as? NSNumber { return n.intValue }
        if let i = info[key] as? Int { return i }
      }
      return 0
    }

    func cleanup() {
      hardTimeout?.cancel()
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
      if latestValue > 0 {
        QCSDKCmdCreator.endBloodOxygenMeasuring(
          withSoa2: CGFloat(latestValue),
          success: nil,
          fail: nil
        )
      }
    }

    func finishOk(_ value: Int) {
      guard !replied, value > 0, value <= 100 else { return }
      replied = true
      latestValue = value
      cleanup()
      finishResult(result, ["spo2": value, "value": value])
      finishManualTransition()
    }

    func finishErr(_ code: String, _ message: String) {
      guard !replied else { return }
      replied = true
      cleanup()
      finishResult(result, FlutterError(code: code, message: message, details: nil))
      finishManualTransition()
    }

    let timeoutWork = DispatchWorkItem {
      if latestValue > 0 {
        finishOk(latestValue)
      } else {
        finishErr("SPO2_MANUAL_TIMEOUT", "manual SpO2 timeout")
      }
    }
    hardTimeout = timeoutWork
    mainQueue.asyncAfter(deadline: .now() + 45, execute: timeoutWork)

    _ = OdmBandNotifyCenter.registerNotify()
    spo2Observer = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeSO2),
      object: nil,
      queue: .main
    ) { note in
      let v = extractFromNotification(note)
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
      let v = extractFromNotification(note)
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
        if Date().timeIntervalSince(startedAt) < minMeasureSec {
          return
        }
        finishErr("SPO2_MANUAL_FAIL", "manual SpO2 measuringFail")
      }
    }

    QCSDKCmdCreator.startBloodOxygenMeasuring(success: nil, fail: {
      self.mainQueue.async {
        finishErr("SPO2_MANUAL_START_FAIL", "start SpO2 measuring failed")
      }
    })
  }

  private func runStress(result: @escaping FlutterResult) {
    let manager = QCSDKManager.shareInstance()
    var replied = false
    var latestValue = 0
    var hardTimeout: DispatchWorkItem?
    var stressObserver: NSObjectProtocol?
    var hrvObserver: NSObjectProtocol?
    let pollInterval: TimeInterval = 2
    let maxDuration: TimeInterval = 60
    let startedAt = Date()

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

    func extractFromNotification(_ note: Notification) -> Int {
      let direct = extractStress(note.object)
      if direct > 0 { return direct }
      guard let info = note.userInfo else { return 0 }
      for key in ["value", "stress", "pressure"] {
        let v = extractStress(info[key])
        if v > 0 { return v }
      }
      for val in info.values {
        let v = extractStress(val)
        if v > 0 { return v }
      }
      return 0
    }

    func cleanupObservers() {
      hardTimeout?.cancel()
      if let obs = stressObserver {
        NotificationCenter.default.removeObserver(obs)
        stressObserver = nil
      }
      if let obs = hrvObserver {
        NotificationCenter.default.removeObserver(obs)
        hrvObserver = nil
      }
      clearManualMeasuringHooks(manager)
      manager.stopToMeasuring(withOperateType: .stress) { _, _ in }
    }

    func finishOk(_ value: Int) {
      guard !replied, value > 0 else { return }
      replied = true
      cleanupObservers()
      finishResult(result, ["pressure": value, "value": value])
      finishManualTransition()
    }

    func finishErr(_ code: String, _ message: String) {
      guard !replied else { return }
      replied = true
      cleanupObservers()
      finishResult(result, FlutterError(code: code, message: message, details: nil))
      finishManualTransition()
    }

    func readScheduledOnce(repeatPoll: Bool = true) {
      guard !replied else { return }
      QCSDKCmdCreator.getSchedualStressData(withDates: [0]) { data, error in
        self.mainQueue.async {
          guard !replied else { return }
          if error == nil,
             let list = data as? [QCStressModel],
             let model = list.first,
             let latest = model.stresses.reversed().first(where: { $0.intValue > 0 })?.intValue,
             latest > 0 {
            finishOk(latest)
            return
          }
          if Date().timeIntervalSince(startedAt) >= maxDuration {
            if latestValue > 0 {
              finishOk(latestValue)
            } else if error != nil {
              finishErr("PRESSURE_MANUAL_FAIL", error!.localizedDescription)
            } else {
              finishErr("PRESSURE_MANUAL_EMPTY", "no stress data")
            }
            return
          }
          if repeatPoll {
            self.mainQueue.asyncAfter(deadline: .now() + pollInterval) {
              readScheduledOnce(repeatPoll: repeatPoll)
            }
          }
        }
      }
    }

    let timeoutWork = DispatchWorkItem {
      if latestValue > 0 {
        finishOk(latestValue)
      } else {
        finishErr("PRESSURE_MANUAL_EMPTY", "no stress data after timeout")
      }
    }
    hardTimeout = timeoutWork
    mainQueue.asyncAfter(deadline: .now() + maxDuration, execute: timeoutWork)

    _ = OdmBandNotifyCenter.registerNotify()
    stressObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeStress),
      object: nil,
      queue: .main
    ) { note in
      let v = extractFromNotification(note)
      if v > 0 {
        latestValue = v
        finishOk(v)
      }
    }
    hrvObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(OdmBandRealTimeHRV),
      object: nil,
      queue: .main
    ) { _ in
      self.mainQueue.asyncAfter(deadline: .now() + 2) {
        readScheduledOnce(repeatPoll: false)
      }
    }

    QCSDKCmdCreator.setSchedualHRVStatus(true) { _ in }
    QCSDKCmdCreator.setSchedualStressStatus(true) { _ in }

    manager.measuringFail = {
      self.mainQueue.async {
        if latestValue > 0 { finishOk(latestValue) }
      }
    }

    manager.startToMeasuring(
      withOperateType: .stress,
      timeout: Int(maxDuration),
      measuringHandle: { measuringResult in
        let v = extractStress(measuringResult)
        if v > 0 { latestValue = v }
        self.mainQueue.async { if v > 0 { finishOk(v) } }
      },
      completedHandle: { _, finalResult, error in
        self.mainQueue.async {
          let finalValue = extractStress(finalResult)
          if finalValue > 0 {
            finishOk(finalValue)
            return
          }
          if latestValue > 0 {
            finishOk(latestValue)
            return
          }
          if let err = error, (err as NSError).code == -3 {
            finishErr("PRESSURE_MANUAL_WEAR", err.localizedDescription)
          }
        }
      }
    )

    mainQueue.asyncAfter(deadline: .now() + 3) {
      readScheduledOnce()
    }
  }
}
