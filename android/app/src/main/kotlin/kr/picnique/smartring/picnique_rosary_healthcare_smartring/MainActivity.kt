// Android entry — BLE handled in Dart (lib/ring/). FG service channels only.
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val BLE_CHANNEL = "com.example.picnique_ring/ble"
        const val FOREGROUND_CHANNEL = "com.example.picnique_ring/foreground_service_channel"
        const val BACKGROUND_CHANNEL = "com.example.picnique_ring/background_keepalive"
    }

    private var selectedBackend: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Both SDKs are selected by Dart. Never resurrect the retired OEM bridge.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "picnique/backend")
            .setMethodCallHandler { call, result ->
                if (call.method != "selectBackend") {
                    result.notImplemented()
                } else {
                    val backend = call.argument<String>("backend")
                    if (backend != "qring" && backend != "rwfit") {
                        result.error("invalid_backend", "Unknown BLE backend", null)
                    } else if (selectedBackend != null && selectedBackend != backend) {
                        result.error("backend_locked", "Restart the application to change BLE backend", null)
                    } else {
                        selectedBackend = backend
                        result.success(true)
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "ensureIgnoreBatteryOptimizations" ->
                        result.success(ensureIgnoreBatteryOptimizations())
                    else -> result.notImplemented()
                }
            }

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

    /** true = already exempt; false = settings intent shown, user must confirm. */
    private fun ensureIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return true
        return try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
            false
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
            }
            false
        }
    }
}
