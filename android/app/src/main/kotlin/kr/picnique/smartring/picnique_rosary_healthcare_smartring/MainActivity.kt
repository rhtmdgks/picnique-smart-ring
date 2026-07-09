// Android entry — BLE handled in Dart (lib/ring/). FG service channels only.
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val FOREGROUND_CHANNEL = "com.example.picnique_ring/foreground_service_channel"
        const val BACKGROUND_CHANNEL = "com.example.picnique_ring/background_keepalive"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, MyForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(this, MyForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startBackgroundKeepalive" -> {
                        val address = call.argument<String>("address")
                        val name = call.argument<String>("name")
                        RingBackgroundPrefs.setKeepalive(this, true, address, name)
                        val intent = Intent(this, MyForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopBackgroundKeepalive" -> {
                        RingBackgroundPrefs.setKeepalive(this, false, null, null)
                        val intent = Intent(this, MyForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "fetchPendingHealthRecords" -> {
                        result.success(PendingHealthQueue.readAll(this))
                    }
                    "fetchPendingHealthSnapshot" -> {
                        val (records, lineCount) = PendingHealthQueue.snapshot(this)
                        result.success(
                            mapOf(
                                "records" to records,
                                "fetchedLineCount" to lineCount,
                            ),
                        )
                    }
                    "clearPendingHealthRecords" -> {
                        PendingHealthQueue.clear(this)
                        result.success(true)
                    }
                    "replacePendingHealthRecords" -> {
                        @Suppress("UNCHECKED_CAST")
                        val records = call.argument<List<Map<String, Any?>>>("records")
                            ?: emptyList()
                        val fetched = call.argument<Int>("fetchedLineCount")
                            ?: Int.MAX_VALUE
                        PendingHealthQueue.replaceAll(this, records, fetched)
                        result.success(true)
                    }
                    "collectPendingHealthNow" -> {
                        // BLE sync moved to Dart RingRepository — no native collect.
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
