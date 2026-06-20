package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File

object PendingHealthQueue {
    private const val FILE = "ring_pending_health.jsonl"
    private val gson = Gson()

    fun append(context: Context, record: Map<String, Any?>) {
        val file = File(context.filesDir, FILE)
        file.appendText(gson.toJson(record) + "\n")
    }

    fun readAll(context: Context): List<Map<String, Any?>> {
        val file = File(context.filesDir, FILE)
        if (!file.exists()) return emptyList()
        val type = object : TypeToken<Map<String, Any?>>() {}.type
        return file.readLines()
            .mapNotNull { line ->
                val trimmed = line.trim()
                if (trimmed.isEmpty()) return@mapNotNull null
                try {
                    gson.fromJson<Map<String, Any?>>(trimmed, type)
                } catch (_: Throwable) {
                    null
                }
            }
    }

    fun clear(context: Context) {
        val file = File(context.filesDir, FILE)
        if (file.exists()) file.delete()
    }

    fun replaceAll(context: Context, records: List<Map<String, Any?>>) {
        val file = File(context.filesDir, FILE)
        if (records.isEmpty()) {
            clear(context)
            return
        }
        val text = records.joinToString("\n") { gson.toJson(it) } + "\n"
        file.writeText(text)
    }
}
