import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';

class DbManager {
  DbManager._();
  static final DbManager I = DbManager._();

  AppDatabase? _db;

  /// 앱 시작 시 한 번 호출
  Future<void> open() async {
    _db ??= AppDatabase();
  }

  /// 테스트용 — in-memory DB 등으로 교체.
  @visibleForTesting
  void setForTesting(AppDatabase? db) {
    _db = db;
  }

  /// 앱 종료 전에 닫기 (선택)
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  AppDatabase get appDB => _db ?? (throw StateError('DbManager.open()을 먼저 호출하세요.'));
  // 기존 호출 호환
  AppDatabase get sleepDB => appDB;
  AppDatabase get heartDB => appDB;
}
