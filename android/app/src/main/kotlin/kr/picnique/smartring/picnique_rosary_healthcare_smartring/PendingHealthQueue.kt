package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File

object PendingHealthQueue {
    private const val FILE = "ring_pending_health.jsonl"
    private val gson = Gson()

    // append(백그라운드 수집)와 fetch/replace(main)가 겹치므로 직렬화.
    private val lock = Any()

    fun append(context: Context, record: Map<String, Any?>) {
        synchronized(lock) {
            val file = File(context.filesDir, FILE)
            file.appendText(gson.toJson(record) + "\n")
        }
    }

    private fun rawLines(context: Context): List<String> {
        val file = File(context.filesDir, FILE)
        if (!file.exists()) return emptyList()
        return file.readLines().filter { it.isNotBlank() }
    }

    private fun parse(lines: List<String>): List<Map<String, Any?>> {
        val type = object : TypeToken<Map<String, Any?>>() {}.type
        return lines.mapNotNull { line ->
            try {
                gson.fromJson<Map<String, Any?>>(line.trim(), type)
            } catch (_: Throwable) {
                null
            }
        }
    }

    fun readAll(context: Context): List<Map<String, Any?>> =
        synchronized(lock) { parse(rawLines(context)) }

    /** 큐 스냅샷 — 레코드 목록 + 원본 라인 수(ACK 시 tail 보존 기준). */
    fun snapshot(context: Context): Pair<List<Map<String, Any?>>, Int> =
        synchronized(lock) {
            val lines = rawLines(context)
            parse(lines) to lines.size
        }

    fun clear(context: Context) {
        synchronized(lock) {
            val file = File(context.filesDir, FILE)
            if (file.exists()) file.delete()
        }
    }

    /**
     * ACK — 스냅샷 처리분을 remaining 으로 교체하되, fetch 이후 append 된
     * tail(라인 [fetchedLineCount] 이후)은 보존한다. 유실 방지.
     */
    fun replaceAll(
        context: Context,
        records: List<Map<String, Any?>>,
        fetchedLineCount: Int = Int.MAX_VALUE,
    ) {
        synchronized(lock) {
            val file = File(context.filesDir, FILE)
            val current = rawLines(context)
            val tail = if (fetchedLineCount < current.size) {
                current.subList(fetchedLineCount, current.size)
            } else {
                emptyList()
            }
            val lines = records.map { gson.toJson(it) } + tail
            if (lines.isEmpty()) {
                if (file.exists()) file.delete()
                return
            }
            file.writeText(lines.joinToString("\n") + "\n")
        }
    }
}
