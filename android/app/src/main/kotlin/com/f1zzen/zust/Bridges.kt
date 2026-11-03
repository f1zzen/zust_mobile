package com.f1zzen.zust

import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL

/**
 * Мосты TOR. Схема в два этапа:
 *  1. подключиться через то, что есть: сохранённые рабочие мосты → воркер Z.UST →
 *     bridges.torproject.org напрямую (в России часто недоступен);
 *  2. уже через сам TOR (SOCKS 127.0.0.1:9050) скачать свежие мосты и сохранить их -
 *     следующее подключение начнётся с них.
 */
object Bridges {
    private const val WORKER_URL = "https://winter-cherry-c701.f1zzencontact.workers.dev/"
    private val TORPROJECT = listOf("obfs4", "webtunnel", "vanilla")
        .map { "https://bridges.torproject.org/bridges?transport=$it" }

    private val PATTERNS = listOf(
        Regex("""obfs4\s+[0-9a-fA-F.:\[\]]+\s+[0-9a-fA-F]{40}\s+cert=\S+\s+iat-mode=\d"""),
        Regex("""webtunnel\s+[0-9a-fA-F.:\[\]]+\s+[0-9a-fA-F]{40}\s+url=https://[^\s<"]+(\s+ver=[0-9.]+)?"""),
        Regex("""(?<![\w.])\d{1,3}(\.\d{1,3}){3}:\d+\s+[0-9a-fA-F]{40}"""),
    )

    /** Сохранённые мосты (последние рабочие и полученные через TOR). */
    fun cached(dir: File): List<String> =
        File(dir, "bridges.txt").takeIf { it.exists() }?.readLines()
            ?.map { it.trim() }?.filter { supported(it) } ?: emptyList()

    fun save(dir: File, bridges: List<String>) {
        File(dir, "bridges.txt").writeText(bridges.distinct().take(200).joinToString("\n"))
    }

    /** Поддерживает ли наш набор (tor + lyrebird) этот мост. */
    fun supported(b: String): Boolean {
        val kind = b.substringBefore(' ')
        return kind == "obfs4" || kind == "webtunnel" ||
            Regex("""^\d{1,3}(\.\d{1,3}){3}:\d+$""").matches(kind)
    }

    /** Скачать мосты из всех источников сразу (параллельно). [viaTor] - через SOCKS работающего TOR. */
    fun fetch(log: (String) -> Unit, viaTor: Boolean = false): List<String> {
        val proxy = if (viaTor) Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", 9050)) else Proxy.NO_PROXY
        val tag = if (viaTor) "через TOR" else "напрямую"
        val pool = java.util.concurrent.Executors.newFixedThreadPool(4)
        try {
            val worker = pool.submit<List<String>> {
                try {
                    val json = JSONObject(get(WORKER_URL, proxy, "Zust/1.0" /* воркер пропускает только эту строку */))
                    val arr = json.optJSONArray("bridges")
                    val out = if (arr == null) emptyList() else (0 until arr.length()).map { clean(arr.getString(it)) }
                    log("Мосты от воркера ($tag): ${out.size}")
                    out
                } catch (e: Exception) {
                    log("Воркер недоступен ($tag): ${e.message}")
                    emptyList()
                }
            }
            val direct = TORPROJECT.map { url ->
                pool.submit<List<String>> {
                    try {
                        val html = get(url, proxy, "Mozilla/5.0 (Android 14; Mobile) Firefox/130.0")
                            .replace("&#43;", "+").replace("&amp;", "&").replace("&quot;", "\"")
                        PATTERNS.flatMap { p -> p.findAll(html).map { clean(it.value) }.toList() }
                    } catch (_: Exception) {
                        emptyList()
                    }
                }
            }
            val all = worker.get().toMutableList()
            val fromTp = direct.flatMap { it.get() }
            log(if (fromTp.isNotEmpty()) "Мосты с torproject.org ($tag): ${fromTp.size}" else "torproject.org недоступен ($tag)")
            all += fromTp
            return all.filter { supported(it) }.distinct()
        } finally {
            pool.shutdown()
        }
    }

    fun forget(dir: File) = File(dir, "bridges.txt").delete()

    private fun clean(b: String) = b.trim().removePrefix("Bridge ").trim()

    private fun get(url: String, proxy: Proxy, ua: String): String {
        val c = URL(url).openConnection(proxy) as HttpURLConnection
        c.connectTimeout = 10_000
        c.readTimeout = 12_000
        c.setRequestProperty("User-Agent", ua)
        c.setRequestProperty("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
        try {
            if (c.responseCode != 200) throw RuntimeException("HTTP ${c.responseCode}")
            return c.inputStream.bufferedReader().readText()
        } finally {
            c.disconnect()
        }
    }
}
