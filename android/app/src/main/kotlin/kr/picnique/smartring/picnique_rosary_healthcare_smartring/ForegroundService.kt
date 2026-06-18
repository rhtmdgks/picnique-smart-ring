// ForegroundService.kt
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.util.Calendar
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

class MyForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "com.example.picnique_ring/foreground_service_channel"
        const val PERIODIC_CHANNEL_ID = "com.example.picnique_ring/periodic_reminder_channel"
        const val FOREGROUND_NOTI_ID = 1
        const val PERIODIC_NOTI_ID = 2

        private const val BASE_URL = "https://www.taeanaihealth.or.kr"
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private lateinit var bridge: BleBridge

    private val httpClient = okhttp3.OkHttpClient()
    private val gson = com.google.gson.Gson()

    override fun onCreate() {
        super.onCreate()
        bridge = BleBridge(applicationContext)

        createNotificationChannel()
        startAsForeground()
        startPeriodicNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 특별히 처리할 intent 없으면 그냥 STICKY
        return START_STICKY
    }

    // suspend: 코루틴 안에서 호출
    private suspend fun loginAndGetAccessToken(
        userId: String,
        password: String
    ): String? = withContext(Dispatchers.IO) {
        try {
            val url = "$BASE_URL/users/login"

            val jsonBody = gson.toJson(
                mapOf(
                    "user_id" to userId,
                    "password" to password
                )
            )

            val mediaType = "application/json; charset=utf-8".toMediaType()
            val body = jsonBody.toRequestBody(mediaType)

            val request = okhttp3.Request.Builder()
                .url(url)
                .post(body)
                .addHeader("Content-Type", "application/json")
                .build()

            val response = httpClient.newCall(request).execute()
            val code = response.code
            val respBody = response.body?.string() ?: ""

            android.util.Log.d("MyForegroundService", "🔎 로그인 응답코드: $code")
            android.util.Log.d("MyForegroundService", "응답: $respBody")

            if (code == 200 || code == 201) {
                val obj = com.google.gson.JsonParser.parseString(respBody).asJsonObject
                // Flutter에서 tokens["accessToken"] 쓰던 그 필드
                return@withContext obj.get("accessToken")?.asString
            } else {
                return@withContext null
            }
        } catch (t: Throwable) {
            android.util.Log.e("MyForegroundService", "loginAndGetAccessToken error", t)
            return@withContext null
        }
    }

    private suspend fun postHealthData(
        accessToken: String,
        data: Map<String, Any?>
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            val url = "$BASE_URL/users/data"

            val jsonBody = gson.toJson(data)

            val mediaType = "application/json; charset=utf-8".toMediaType()
            val body = jsonBody.toRequestBody(mediaType)

            val request = okhttp3.Request.Builder()
                .url(url)
                .post(body)
                .addHeader("Content-Type", "application/json")
                .addHeader("Authorization", "Bearer $accessToken")
                .build()

            val response = httpClient.newCall(request).execute()
            val code = response.code
            val respBody = response.body?.string() ?: ""

            android.util.Log.d("MyForegroundService", "📡 /users/data 응답코드: $code")
            android.util.Log.d("MyForegroundService", "응답: $respBody")

            return@withContext (code in 200..299)
        } catch (t: Throwable) {
            android.util.Log.e("MyForegroundService", "postHealthData error", t)
            return@withContext false
        }
    }

    

    private fun startAsForeground() {
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("30분 알림 서비스 실행 중")
            .setContentText("앱이 백그라운드에서 30분마다 알림을 보냅니다.")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setOngoing(true) // 사용자가 알림 스와이프로 지우지 못하게(필수는 아님)
            .build()

        startForeground(FOREGROUND_NOTI_ID, notification)
    }

    private fun startPeriodicNotification() {
        serviceScope.launch {
            while (isActive) {
                // 현재 시간
                val now = System.currentTimeMillis()
                val calendar = Calendar.getInstance().apply {
                    timeInMillis = now
                }

                // 현재 분
                val minute = calendar.get(Calendar.MINUTE)

                // 다음 알림 시각 계산
                when {
                    minute < 30 -> {
                        // 다음 알림은 xx:30
                        calendar.set(Calendar.MINUTE, 30)
                        calendar.set(Calendar.SECOND, 0)
                        calendar.set(Calendar.MILLISECOND, 0)
                    }

                    else -> {
                        // 다음 알림은 다음 시간의 00분
                        calendar.add(Calendar.HOUR_OF_DAY, 1)
                        calendar.set(Calendar.MINUTE, 0)
                        calendar.set(Calendar.SECOND, 0)
                        calendar.set(Calendar.MILLISECOND, 0)
                    }
                }

                val nextTrigger = calendar.timeInMillis
                val diff = (nextTrigger - now).coerceAtLeast(0L) // 음수 방지

                // 다음 정각/30분까지 대기
                delay(diff)
                
                // delay(5 * 60 * 1000L) // 5분 = 300,000ms
                // 🔥 저장된 값들 기준 최신 건강 데이터 JSON 생성
                val jsonMap: Map<String, Any?> = try {
                    withContext(Dispatchers.IO) {
                        // 여기서 buildStoredHealthJsonMap 은 아까 만든 코틀린 확장 함수
                        bridge.buildStoredHealthJsonMap("taiipa001")
                    }
                } catch (t: Throwable) {
                    Log.e("MyForegroundService", "buildStoredHealthJsonMap failed", t)
                    emptyMap()
                }

                Log.d("HealthSnapshot", jsonMap.toString())

                if (jsonMap.isNotEmpty()) {
                    // 알림 발송
                    sendPeriodicNotification(jsonMap)
                }
            }
        }
    }

    // 🔥 이제 네트워크도 같이 하니까 suspend 로 변경
    private suspend fun sendPeriodicNotification(data: Map<String, Any?>) {
        // 1) 매 번 로그인하는 구조 (간단 버전)
        //    실서비스에선 토큰 캐싱/만료처리 하는 게 좋음
        val userId = "taiipa001"      // TODO: 실제 유저 ID
        val password = "taiipa@01"      // TODO: 실제 유저 비번 or 안전한 저장소에서 읽기

        val accessToken = loginAndGetAccessToken(userId, password)
        if (accessToken == null) {
            android.util.Log.e("MyForegroundService", "❌ 로그인 실패, 데이터 전송 안 함")
        } else {
            val ok = postHealthData(accessToken, data)
            android.util.Log.d("MyForegroundService", "📡 /users/data 전송 결과: $ok")
        }

        // 2) 알림 표시 (기존 로직 유지)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val text =
            "HR=${data["heart_rate"]}, SpO2=${data["spo2"]}, Steps=${data["step_count"]}"

        val notification = NotificationCompat.Builder(this, PERIODIC_CHANNEL_ID)
            .setContentTitle("건강 데이터 스냅샷")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        manager.notify(PERIODIC_NOTI_ID, notification)
    }


    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Foreground Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)

            val periodicChannel = NotificationChannel(
                PERIODIC_CHANNEL_ID,
                "Periodic Reminder Channel",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(periodicChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
