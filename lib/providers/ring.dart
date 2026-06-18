import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:picnique_rosary_healthcare_smartring/_mock/mockRing.dart';

class Ring with ChangeNotifier {
  static const _kAddress = 'ring_address';
  static const _kName = 'ring_name';
  static const _kBattery = 'ring_battery';

  String? _name, _address;
  int? _battery;
  bool _isConnected = false;

  String id = "taiipa001";
  String pwd = "taiipa@01";
  String? _accessToken;

  String? get name => _name;
  String? get address => _address;
  int? get battery => _battery;
  bool get isConnected => _isConnected;
  String? get accessToken => _accessToken;

  void setName(newName) {
    _name = newName;
    notifyListeners();
  }

  void setAddress(newAddress) {
    _address = newAddress;
    notifyListeners();
  }

  void setBattery(newBattery) {
    _battery = newBattery;
    notifyListeners();
  }

  void setIsConnected(newIsConnected) {
    _isConnected = newIsConnected;
    notifyListeners();
  }

  void setAccessToken(newAccessToken) {
    _accessToken = newAccessToken;
    notifyListeners();
  }

  void resetRing() {
    _name = null;
    _address = null;
    _battery = null;
    _isConnected = false;
    _accessToken = null;
    notifyListeners();
  }

  void getMockRing() {
    setIsConnected(true);
    setName(MockRing.name);
    setAddress(MockRing.address);
    setBattery(MockRing.battery);
  }

  /// 앱 시작 시 마지막 연결 기기 정보를 복원한다.
  /// 연결 상태(isConnected)는 복원하지 않는다(콜드 스타트는 미연결).
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _address = prefs.getString(_kAddress);
    _name = prefs.getString(_kName);
    _battery = prefs.containsKey(_kBattery) ? prefs.getInt(_kBattery) : null;
    notifyListeners();
  }

  /// 마지막 연결 기기 정보를 저장한다(빠른 재연결용).
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
  }
}
