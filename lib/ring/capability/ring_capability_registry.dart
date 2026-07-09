// Source: Gadgetbridge AbstractYawellRingCoordinator (AGPL-3.0)
// Source: atc1441/ATC_RF03_Ring Known_BLE_OEM_Ring_Names.txt

import 'known_device_names.dart';
import 'ring_probe_capabilities.dart';

enum RingModel {
  r01,
  r02,
  r03,
  r04,
  r05,
  r06,
  r07,
  r08,
  r09,
  r10,
  r11,
  r12,
  h59,
  oem,
  unknown,
}

class RingCapabilities {
  const RingCapabilities({
    required this.model,
    required this.supportsSpo2,
    required this.supportsStress,
    required this.supportsHrv,
    required this.supportsTemperature,
    required this.supportsSleep,
    required this.supportsRawAccelerometer,
    this.newSleepProtocol = true,
    this.supportsManualHeart = true,
  });

  final RingModel model;
  final bool supportsSpo2;
  final bool supportsStress;
  final bool supportsHrv;
  final bool supportsTemperature;
  final bool supportsSleep;
  final bool supportsRawAccelerometer;
  final bool newSleepProtocol;
  final bool supportsManualHeart;

  /// QRing default — assume full RF03 feature set until probe says otherwise.
  factory RingCapabilities.qringDefault([RingModel model = RingModel.unknown]) {
    return RingCapabilities(
      model: model,
      supportsSpo2: true,
      supportsStress: true,
      supportsHrv: true,
      supportsTemperature: true,
      supportsSleep: true,
      supportsRawAccelerometer: true,
      newSleepProtocol: true,
      supportsManualHeart: true,
    );
  }

  RingCapabilities mergeProbe(RingProbeCapabilities probe) {
    return RingCapabilities(
      model: model,
      supportsSpo2: probe.supportsSpo2,
      supportsStress: probe.supportsStress,
      supportsHrv: probe.supportsHrv || supportsHrv,
      supportsTemperature: probe.supportsTemperature || supportsTemperature,
      supportsSleep: supportsSleep,
      supportsRawAccelerometer: supportsRawAccelerometer,
      newSleepProtocol: probe.newSleepProtocol,
      supportsManualHeart: probe.supportsManualHeart,
    );
  }
}

/// QRing-compatible capability registry — optimistic defaults, probe refines.
abstract final class RingCapabilityRegistry {
  static RingCapabilities resolve(String? deviceName) {
    final model = detectModel(deviceName);
    // GB AbstractYawellRingCoordinator: almost everything true for all models.
    final base = RingCapabilities.qringDefault(model);
    if (model == RingModel.r05 || model == RingModel.r09) {
      return base.copyWith(supportsTemperature: true);
    }
    if (model == RingModel.r02 || model == RingModel.r03 || model == RingModel.r06) {
      return base.copyWith(supportsTemperature: false, supportsHrv: false);
    }
    return base;
  }

  static RingCapabilities resolveWithProbe(
    String? deviceName,
    RingProbeCapabilities? probe,
  ) {
    var caps = resolve(deviceName);
    if (probe != null) caps = caps.mergeProbe(probe);
    return caps;
  }

  static bool isSupportedDevice(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    return KnownDeviceNames.matches(name) || _looksLikeYawellName(name);
  }

  static RingModel detectModel(String? name) {
    if (name == null) return RingModel.unknown;
    final upper = name.toUpperCase();
    if (upper.contains('H59')) return RingModel.h59;
    for (final entry in [
      ('R12', RingModel.r12),
      ('R11', RingModel.r11),
      ('R10', RingModel.r10),
      ('R09', RingModel.r09),
      ('R08', RingModel.r08),
      ('R07', RingModel.r07),
      ('R06', RingModel.r06),
      ('R05', RingModel.r05),
      ('R04', RingModel.r04),
      ('R03', RingModel.r03),
      ('R02', RingModel.r02),
      ('R01', RingModel.r01),
    ]) {
      if (upper.contains(entry.$1)) return entry.$2;
    }
    if (KnownDeviceNames.matches(name)) return RingModel.oem;
    if (_looksLikeYawellName(name)) return RingModel.oem;
    return RingModel.unknown;
  }

  static bool _looksLikeYawellName(String name) {
    final upper = name.toUpperCase();
    return upper.contains('RING') ||
        upper.contains('COLMI') ||
        upper.contains('YAWELL') ||
        upper.startsWith('R0') ||
        upper.startsWith('R1');
  }
}

extension on RingCapabilities {
  RingCapabilities copyWith({
    bool? supportsSpo2,
    bool? supportsStress,
    bool? supportsHrv,
    bool? supportsTemperature,
    bool? supportsSleep,
    bool? supportsRawAccelerometer,
    bool? newSleepProtocol,
    bool? supportsManualHeart,
  }) {
    return RingCapabilities(
      model: model,
      supportsSpo2: supportsSpo2 ?? this.supportsSpo2,
      supportsStress: supportsStress ?? this.supportsStress,
      supportsHrv: supportsHrv ?? this.supportsHrv,
      supportsTemperature: supportsTemperature ?? this.supportsTemperature,
      supportsSleep: supportsSleep ?? this.supportsSleep,
      supportsRawAccelerometer:
          supportsRawAccelerometer ?? this.supportsRawAccelerometer,
      newSleepProtocol: newSleepProtocol ?? this.newSleepProtocol,
      supportsManualHeart: supportsManualHeart ?? this.supportsManualHeart,
    );
  }
}
