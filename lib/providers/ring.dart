import '../integrations/rwfit/ring_backend.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:picnique_rosary_healthcare_smartring/_mock/mockRing.dart';

class Ring with ChangeNotifier {
  Ring() { RingBackend.rwfit?.addListener(_fromRwfit); }
  void _fromRwfit() {
    final session = RingBackend.rwfit;
    if (session == null) return;
    _isConnected = session.ready;
    _sdkReady = session.ready;
    _isReconnecting = false;
    _battery = session.battery;
    _batteryFromRealtime = session.battery != null;
    _name = session.device?.name ?? session.savedDevice?.name;
    final d = session.device ?? session.savedDevice;
    _address = d == null ? null : session.identity(d);
    _savedName = session.savedDevice?.name;
    _savedAddress = session.savedDevice == null ? null : session.identity(session.savedDevice!);
    notifyListeners();
  }
  @override
  void dispose() {
    RingBackend.rwfit?.removeListener(_fromRwfit);
    super.dispose();
  }
  static const _kAddress = 'ring_address';
  static const _kName = 'ring_name';
  static const _kBattery = 'ring_battery';
  static const _kSavedAddress = 'ring.saved_address';
  static const _kSavedName = 'ring.saved_name';

  String? _name, _address;
  int? _battery;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _isCharging = false;
  bool _sdkReady = false;
  bool _batteryFromRealtime = false;
  String? _savedName, _savedAddress;

  String id = "taiipa001";
  String pwd = "taiipa@01";
  String? _accessToken;

  String? get name => _name;
  String? get address => _address;
  int? get battery => _battery;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  bool get isCharging => _isCharging;
  bool get sdkReady => _sdkReady;
  bool get hasFreshBatteryFromDevice => _batteryFromRealtime;
  String? get savedName => _savedName;
  String? get savedAddress => _savedAddress;
  String? get accessToken => _accessToken;

  bool get hasSavedDevice =>
      (_savedAddress?.trim().isNotEmpty ?? false) ||
      (_address?.trim().isNotEmpty ?? false);

  void setName(String? newName) {
    _name = newName;
    notifyListeners();
  }

  void setAddress(String? newAddress) {
    _address = newAddress;
    notifyListeners();
  }

  void setBattery(int? newBattery) {
    setBatteryAndCharging(newBattery, _isCharging);
  }

  void setCharging(bool charging) {
    if (_isCharging == charging) return;
    _isCharging = charging;
    notifyListeners();
    BatteryNotificationService.onChargingState(
      isCharging: charging,
      battery: _battery,
    );
  }

  void setSdkReady(bool ready) {
    if (_sdkReady == ready) return;
    _sdkReady = ready;
    notifyListeners();
  }

  void setBatteryAndCharging(
    int? newBattery,
    bool? charging, {
    bool fromRealtime = false,
  }) {
    final prevCharging = _isCharging;
    final prevBattery = _battery;
    var changed = false;

    if (fromRealtime) {
      _batteryFromRealtime = true;
    }

    final normalized = _normalizeBatteryLevel(newBattery);
    if (normalized != null && normalized != _battery) {
      _battery = normalized;
      changed = true;
    }
    if (charging != null && charging != _isCharging) {
      _isCharging = charging;
      changed = true;
    }
    if (!changed) return;

    notifyListeners();
    unawaited(persist());

    if (charging != null && charging != prevCharging) {
      BatteryNotificationService.onChargingState(
        isCharging: _isCharging,
        battery: _battery,
      );
    } else if (_isCharging && normalized != null && normalized != prevBattery) {
      BatteryNotificationService.onChargingProgress(_battery);
    }

    if (normalized != null && !_isCharging) {
      BatteryNotificationService.onBatteryLevel(normalized);
    }
  }

  int? _normalizeBatteryLevel(int? value) {
    if (value == null) return null;
    if (value < 1 || value > 100) return null;
    return value;
  }

  void setIsConnected(bool newIsConnected) {
    _isConnected = newIsConnected;
    if (newIsConnected) {
      _isReconnecting = false;
    }
    notifyListeners();
  }

  void setIsReconnecting(bool value) {
    if (_isReconnecting == value) return;
    _isReconnecting = value;
    notifyListeners();
  }

  void setAccessToken(String? newAccessToken) {
    _accessToken = newAccessToken;
    notifyListeners();
  }

  Future<void> markConnected({
    required String name,
    required String address,
  }) async {
    final sameDevice = _isConnected &&
        _address != null &&
        _address!.toLowerCase() == address.toLowerCase();
    _name = name;
    _address = address;
    _isConnected = true;
    _isReconnecting = false;
    if (!sameDevice) {
      _sdkReady = false;
      _batteryFromRealtime = false;
    }
    _savedName = name;
    _savedAddress = address;
    if (_battery == null) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_kBattery)) {
        _battery = prefs.getInt(_kBattery);
      }
    }
    await _persistSavedDevice();
    await persist();
    notifyListeners();
  }

  Future<void> markDisconnected({bool forgetSaved = false}) async {
    _name = null;
    _address = null;
    _isConnected = false;
    _isCharging = false;
    _sdkReady = false;
    _batteryFromRealtime = false;
    _accessToken = null;
    if (forgetSaved) {
      _savedName = null;
      _savedAddress = null;
      _isReconnecting = false;
      await _persistSavedDevice();
      await clearPersist();
    } else if (_savedAddress != null && _savedAddress!.isNotEmpty) {
      _isReconnecting = true;
    } else {
      _isReconnecting = false;
    }
    notifyListeners();
  }

  void resetRing() {
    _name = null;
    _address = null;
    _battery = null;
    _isConnected = false;
    _isReconnecting = false;
    _isCharging = false;
    _sdkReady = false;
    _batteryFromRealtime = false;
    _accessToken = null;
    notifyListeners();
  }

  void getMockRing() {
    setIsConnected(true);
    setName(MockRing.name);
    setAddress(MockRing.address);
    setBattery(MockRing.battery);
  }

  Future<void> loadFromPrefs() async {
    if (RingBackend.isRwfit) { _fromRwfit(); return; }
    await restorePersistedDevice();
    final prefs = await SharedPreferences.getInstance();
    _address ??= prefs.getString(_kAddress);
    _name ??= prefs.getString(_kName);
    _battery = prefs.containsKey(_kBattery) ? prefs.getInt(_kBattery) : null;
    notifyListeners();
  }

  Future<void> restorePersistedDevice() async {
    if (RingBackend.isRwfit) { _fromRwfit(); return; }
    final prefs = await SharedPreferences.getInstance();
    _savedAddress = prefs.getString(_kSavedAddress) ??
        prefs.getString(_kAddress);
    _savedName =
        prefs.getString(_kSavedName) ?? prefs.getString(_kName);
    if (_savedAddress != null && _savedAddress!.isNotEmpty) {
      await _persistSavedDevice();
    }
    notifyListeners();
  }

  Future<void> _persistSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    if (_savedName == null || _savedName!.isEmpty) {
      await prefs.remove(_kSavedName);
    } else {
      await prefs.setString(_kSavedName, _savedName!);
    }
    if (_savedAddress == null || _savedAddress!.isEmpty) {
      await prefs.remove(_kSavedAddress);
    } else {
      await prefs.setString(_kSavedAddress, _savedAddress!);
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_address != null) {
      await prefs.setString(_kAddress, _address!);
    }
    if (_name != null) {
      await prefs.setString(_kName, _name!);
    }
    if (_battery != null) {
      await prefs.setInt(_kBattery, _battery!);
    }
  }

  Future<void> clearPersist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAddress);
    await prefs.remove(_kName);
    await prefs.remove(_kBattery);
    await prefs.remove(_kSavedAddress);
    await prefs.remove(_kSavedName);
  }
}
