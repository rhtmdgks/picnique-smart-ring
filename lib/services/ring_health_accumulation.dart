import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';

/// 연결 상태에서 반지 내부 메모리 → 앱 DB 축적을 한 번에 수행한다.
///
/// 1. 네이티브 `collectHealthIfIdle` — 반지 저장 데이터를 pending 큐로 pull
///    (네이티브 세션·watermark 가 중복 수집을 막는다)
/// 2. [RingPendingImport.importAll] — 큐 → Drift DB 병합 + ACK
///
/// 수집은 자동 우선순위(BLE 큐)로 실행되어 수동 측정이 들어오면 즉시
/// 선점된다. 수집이 중단돼도 이미 큐에 쌓인 분은 import 한다.
class RingHealthAccumulation {
  static Future<int> flushConnectedToApp({
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
    bool force = false,
  }) async {
    if (ring != null && ring.isConnected && ring.sdkReady) {
      try {
        await BleCommandQueue.invokeAuto<dynamic>('collectHealthIfIdle', {
          'force': force,
        });
      } on PlatformException catch (e) {
        if (e.code == BleCommandQueue.autoCancelledCode) {
          debugPrint('[HEALTH_ACC] collect preempted by manual measurement');
        } else {
          debugPrint('[HEALTH_ACC] collect failed: ${e.code} ${e.message}');
        }
      } catch (e) {
        debugPrint('[HEALTH_ACC] collect error: $e');
      }
    } else {
      debugPrint('[HEALTH_ACC] skip collect — not connected/ready');
    }

    // 수집 성공 여부와 무관하게 큐에 남은 분은 병합한다.
    return RingPendingImport.importAll(
      ring: ring,
      refreshNotifier: refreshNotifier,
    );
  }
}
