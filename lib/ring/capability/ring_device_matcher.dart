// Source: colmi_r06_fbp advertisedNamePattern (BSD-3-Clause)
// R08 실측: 광고에는 fee7만 노출, 6e40/de5bf는 connect 후 discovery.

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Yawell/Colmi RF03 ring scan matching.
///
/// Scan: **no GATT UUID filter** (R08 등은 광고에 6e40/de5bf 없음).
/// Adopt: [advName] 또는 [platformName] 이 `R0` 으로 시작하는 기기만.
abstract final class RingDeviceMatcher {
  static final RegExp _r0Prefix = RegExp(r'^R0', caseSensitive: false);

  /// True when advertised or platform name starts with `R0` (e.g. R02_, R08_).
  static bool isYawellRing(ScanResult result) {
    final adv = result.advertisementData.advName.trim();
    if (adv.isNotEmpty && _r0Prefix.hasMatch(adv)) return true;
    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty && _r0Prefix.hasMatch(platform)) return true;
    return false;
  }

  /// Open scan — do not pass [withServices]; connected GATT differs from adv.
  static List<Guid>? get scanServiceFilter => null;
}

/// @deprecated Use [RingDeviceMatcher.isYawellRing]
typedef ColmiDeviceMatcher = RingDeviceMatcher;
