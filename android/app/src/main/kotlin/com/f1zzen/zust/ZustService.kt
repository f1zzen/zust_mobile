package com.f1zzen.zust

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.TrafficStats
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.thread

/**
 * Всё, что должно жить без открытого приложения: TOR, подбор мостов и VPN.
 * Работает как foreground-сервис с уведомлением - иначе Android (особенно Xiaomi,
 * Huawei, Samsung) убивает процесс, как только приложение свёрнуто.
 *
 * Режимы: "proxy" - только SOCKS 127.0.0.1:9050 (Telegram и т.п.), "vpn" - весь трафик
 * выбранных приложений через TOR (tun → hev-socks5-tunnel → SOCKS).
 */
class ZustService : VpnService() {

    // ---------- состояние, общее с интерфейсом ----------
    companion object {
        const val ACTION_START = "com.f1zzen.zust.START"
        const val ACTION_STOP = "com.f1zzen.zust.STOP"
        private const val CHANNEL = "zust_status"
        private const val NOTIFY_ID = 1
        private const val MAX_LOG = 400
        /** Нет нового прогресса столько времени - мосты не работают, берём следующие. */
        private const val STALL_MS = 70_000L
        private const val BATCH = 25

        /** 0 - выключен, 1 - подключение, 2 - работает */
        @Volatile var state = 0; private set
        @Volatile var progress = 0; private set
        @Volatile var mode = "proxy"; private set
        val logs = ArrayList<String>()
        val listeners = CopyOnWriteArrayList<(Map<String, Any>) -> Unit>()
        private val main = Handler(Looper.getMainLooper())

        /** Трафик приложения (tor и мосты идут от его имени) на момент включения. */
        @Volatile private var rx0 = 0L
        @Volatile private var tx0 = 0L

        private fun uidBytes(rx: Boolean): Long {
            val uid = android.os.Process.myUid()
            return (if (rx) TrafficStats.getUidRxBytes(uid) else TrafficStats.getUidTxBytes(uid)).coerceAtLeast(0)
        }

        fun snapshot(): Map<String, Any> = mapOf(
            "state" to state, "progress" to progress, "mode" to mode,
            "log" to synchronized(logs) { logs.lastOrNull() ?: "" },
            "rx" to if (state == 0) 0L else (uidBytes(true) - rx0).coerceAtLeast(0),
            "tx" to if (state == 0) 0L else (uidBytes(false) - tx0).coerceAtLeast(0),
        )

        /** Пока включено - раз в секунду свежий трафик для интерфейса и кнопки в шторке. */
        private val tick = object : Runnable {
            override fun run() {
                if (state == 0) return
                publish()
                main.postDelayed(this, 1000)
            }
        }

        private fun publish(extra: Map<String, Any> = emptyMap()) {
            val event = snapshot() + extra
            main.post { listeners.forEach { it(event) } }
        }

        fun start(ctx: Context, mode: String, apps: List<String>) {
            val i = Intent(ctx, ZustService::class.java).setAction(ACTION_START)
                .putExtra("mode", mode).putStringArrayListExtra("apps", ArrayList(apps))
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.startService(Intent(ctx, ZustService::class.java).setAction(ACTION_STOP))
        }
    }

    private var tor: Process? = null
    private var tun: ParcelFileDescriptor? = null
    private var hevThread: Thread? = null
    private var apps: List<String> = emptyList()
    /** Растёт при каждой остановке: старые потоки видят это и завершаются. */
    @Volatile private var generation = 0
    @Volatile private var lastProgressAt = 0L

    private val dir by lazy { File(filesDir, "tor").apply { mkdirs() } }
    private val libDir by lazy { applicationInfo.nativeLibraryDir }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                shutdown("Остановлено")
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                mode = intent.getStringExtra("mode") ?: "proxy"
                apps = intent.getStringArrayListExtra("apps") ?: arrayListOf()
                goForeground()
                if (state == 0) launch()
            }
            // перезапуск системой после убийства процесса: поднимаемся заново с теми же настройками
            null -> {
                val p = getSharedPreferences("zust", MODE_PRIVATE)
                mode = p.getString("mode", "proxy") ?: "proxy"
                apps = p.getStringSet("apps", emptySet())?.toList() ?: emptyList()
                goForeground()
                if (state == 0) launch()
            }
        }
        return START_STICKY
    }

    override fun onRevoke() {
        // VPN отключили из настроек системы или включили другой VPN
        log("VPN отключён системой")
        shutdown("VPN отключён")
        stopForegroundCompat()
        stopSelf()
    }

    override fun onDestroy() {
        shutdown(null)
        super.onDestroy()
    }

    // ---------- логи ----------

    private fun log(line: String) {
        android.util.Log.i("Z.UST", line)
        synchronized(logs) {
            logs += line
            if (logs.size > MAX_LOG) logs.subList(0, logs.size - MAX_LOG).clear()
        }
        publish(mapOf("line" to line))
    }

    private fun setState(s: Int, p: Int = progress) {
        state = s; progress = p
        publish()
        updateNotification()
    }

    // ---------- TOR ----------

    private fun launch() {
        val gen = ++generation
        rx0 = uidBytes(true)
        tx0 = uidBytes(false)
        setState(1, 0)
        main.removeCallbacks(tick)
        main.post(tick)
        thread(name = "zust-tor") {
            try {
                prepareFiles()
                // список кандидатов: сохранённые → свежие из сети
                val pool = Bridges.cached(dir).toMutableList()
                log(if (pool.isEmpty()) "Сохранённых мостов нет" else "Сохранённых мостов: ${pool.size}")
                var fetched = false
                var batchStart = 0
                while (gen == generation) {
                    if (batchStart >= pool.size) {
                        if (fetched) {
                            log("Мосты закончились - пробую подключиться без мостов")
                            if (runTor(gen, emptyList())) return@thread
                            if (gen == generation) {
                                log("Не удалось подключиться. Проверьте интернет и попробуйте позже.")
                                main.post { shutdown("Не подключилось"); stopForegroundCompat(); stopSelf() }
                            }
                            return@thread
                        }
                        log("Получаю мосты…")
                        val fresh = Bridges.fetch(::log).filter { it !in pool }.shuffled()
                        pool += fresh
                        fetched = true
                        continue
                    }
                    val batch = pool.subList(batchStart, minOf(pool.size, batchStart + BATCH)).toList()
                    batchStart += BATCH
                    log("Подключаюсь через ${batch.size} мост(ов)…")
                    if (runTor(gen, batch)) return@thread
                }
            } catch (e: Exception) {
                log("Ошибка: ${e.message}")
                if (gen == generation) main.post { shutdown("Ошибка"); stopForegroundCompat(); stopSelf() }
            }
        }
    }

    /** Запускает tor с этими мостами. true - подключился (tor продолжает работать). */
    private fun runTor(gen: Int, bridges: List<String>): Boolean {
        killTor()
        val torrc = File(dir, "torrc")
        torrc.writeText(config(bridges))
        val p = ProcessBuilder("$libDir/libtor.so", "-f", torrc.absolutePath)
            .directory(dir).redirectErrorStream(true).start()
        tor = p
        lastProgressAt = System.currentTimeMillis()
        progress = 0
        publish()
        val bootstrap = Regex("""Bootstrapped (\d+)%""")
        val reader = thread(name = "zust-tor-log") {
            try {
                p.inputStream.bufferedReader().forEachLine { raw ->
                    val line = raw.substringAfter("] ", raw)
                    bootstrap.find(line)?.let {
                        val pct = it.groupValues[1].toInt()
                        if (pct > progress) { progress = pct; lastProgressAt = System.currentTimeMillis() }
                        publish()
                    }
                    log(line)
                }
            } catch (_: Exception) {
            }
        }
        // ждём 100%, смерти процесса или зависания
        while (gen == generation) {
            Thread.sleep(500)
            if (progress >= 100) {
                log("TOR подключён")
                if (bridges.isNotEmpty()) Bridges.save(dir, bridges + Bridges.cached(dir))
                onConnected(gen)
                return true
            }
            if (!p.isAlive) {
                reader.join(1000)
                log("tor завершился (код ${p.exitValue()})")
                return false
            }
            if (System.currentTimeMillis() - lastProgressAt > STALL_MS) {
                log("Подключение зависло на ${progress}% - пробую другие мосты")
                killTor()
                return false
            }
        }
        return false
    }

    private fun onConnected(gen: Int) {
        if (mode == "vpn") startVpn()
        setState(2, 100)
        // этап 2: свежие мосты через сам TOR - для следующих подключений
        thread(name = "zust-bridges") {
            Thread.sleep(5_000)
            if (gen != generation) return@thread
            val fresh = Bridges.fetch(::log, viaTor = true)
            if (fresh.isNotEmpty() && gen == generation) {
                Bridges.save(dir, Bridges.cached(dir).take(BATCH) + fresh)
                log("Сохранено ${fresh.size} свежих мостов для следующего подключения")
            }
        }
    }

    private fun config(bridges: List<String>) = buildString {
        val data = File(dir, "data").apply { mkdirs() }
        appendLine("SocksPort 127.0.0.1:9050")
        appendLine("DataDirectory ${data.absolutePath}")
        appendLine("GeoIPFile ${dir.absolutePath}/geoip")
        appendLine("GeoIPv6File ${dir.absolutePath}/geoip6")
        appendLine("PidFile ${dir.absolutePath}/tor.pid")
        // tor завершится сам, если процесс Z.UST умер (без "осиротевшего" tor)
        appendLine("__OwningControllerProcess ${android.os.Process.myPid()}")
        appendLine("ClientTransportPlugin obfs4,webtunnel exec $libDir/liblyrebird.so")
        if (bridges.isNotEmpty()) {
            appendLine("UseBridges 1")
            appendLine("UpdateBridgesFromAuthority 0")
            bridges.forEach { appendLine("Bridge $it") }
        }
        appendLine("AvoidDiskWrites 1")
        appendLine("SafeLogging 1")
        appendLine("ClientOnly 1")
        appendLine("CircuitBuildTimeout 15")
        appendLine("KeepalivePeriod 30")
        appendLine("Log notice stdout")
    }

    private fun prepareFiles() {
        for (name in listOf("geoip", "geoip6")) {
            val out = File(dir, name)
            if (out.exists() && out.length() > 0) continue
            assets.open("flutter_assets/assets/common/data/$name").use { inp ->
                out.outputStream().use { inp.copyTo(it) }
            }
        }
    }

    private fun killTor() {
        tor?.let { p ->
            p.destroy()
            if (!p.waitForTimeout(3000)) p.destroyForcibly()
        }
        tor = null
        // tor, оставшийся от прошлого запуска (приложение упало)
        val pid = File(dir, "tor.pid").takeIf { it.exists() }?.readText()?.trim()?.toIntOrNull()
        if (pid != null && pid != android.os.Process.myPid()) {
            try { android.os.Process.killProcess(pid) } catch (_: Exception) {}
            File(dir, "tor.pid").delete()
        }
    }

    private fun Process.waitForTimeout(ms: Long): Boolean {
        val end = System.currentTimeMillis() + ms
        while (System.currentTimeMillis() < end) {
            if (!isAlive) return true
            Thread.sleep(50)
        }
        return !isAlive
    }

    // ---------- VPN ----------

    private fun startVpn() {
        val b = Builder()
            .setSession("Z.UST")
            .setMtu(8500)
            .addAddress("198.18.0.1", 32)
            .addRoute("0.0.0.0", 0)
            .addAddress("fc00::1", 128)
            .addRoute("::", 0)
            // DNS отвечает сам hev (mapdns): выдаёт "фейковые" адреса, а имя сайта
            // уходит в TOR - сайты открываются, хотя TOR не умеет UDP
            .addDnsServer("198.18.0.2")
        // либо только выбранные приложения, либо все кроме Z.UST (смешивать нельзя)
        val chosen = apps.filter { it != packageName }
        if (chosen.isNotEmpty()) {
            chosen.forEach { pkg ->
                try { b.addAllowedApplication(pkg) } catch (_: Exception) { log("Приложение не найдено: $pkg") }
            }
        } else {
            try { b.addDisallowedApplication(packageName) } catch (_: Exception) {}
        }
        val fd = b.establish() ?: run { log("VPN не разрешён - откройте Z.UST и подтвердите"); return }
        tun = fd
        val conf = File(cacheDir, "hev.yml").apply {
            writeText(
                """
                tunnel:
                  mtu: 8500
                  ipv4: 198.18.0.1
                  ipv6: 'fc00::1'
                socks5:
                  port: 9050
                  address: 127.0.0.1
                  udp: 'udp'
                mapdns:
                  address: 198.18.0.2
                  port: 53
                  network: 100.64.0.0
                  netmask: 255.192.0.0
                  cache-size: 10000
                misc:
                  task-stack-size: 81920
                  log-level: warn
                """.trimIndent()
            )
        }
        hevThread = thread(name = "zust-hev") {
            val r = HevWrapper().startTunnel(conf.absolutePath, fd.fd)
            log("Туннель остановлен (код $r)")
        }
        log(if (chosen.isEmpty()) "VPN включён для всех приложений" else "VPN включён для ${chosen.size} приложений")
    }

    private fun stopVpn() {
        if (hevThread != null) {
            try { HevWrapper().stopTunnel() } catch (_: Exception) {}
            hevThread?.join(2000)
            hevThread = null
        }
        try { tun?.close() } catch (_: Exception) {}
        tun = null
    }

    private fun shutdown(reason: String?) {
        generation++
        stopVpn()
        killTor()
        if (state != 0) {
            reason?.let { log(it) }
            setState(0, 0)
        }
    }

    // ---------- уведомление ----------

    private fun goForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Состояние Z.UST", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) }
            )
        }
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFY_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFY_ID, notification())
        }
    }

    private fun updateNotification() {
        if (state == 0) return
        getSystemService(NotificationManager::class.java).notify(NOTIFY_ID, notification())
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, ZustService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE
        )
        val text = when (state) {
            2 -> if (mode == "vpn") "TOR работает · VPN" else "TOR работает · прокси 127.0.0.1:9050"
            1 -> "Подключение… $progress%"
            else -> "Запуск…"
        }
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_stat_zust)
            .setContentTitle("Z.UST")
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Остановить", stop).build())
        if (state == 1) b.setProgress(100, progress, progress == 0)
        return b.build()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
    }
}
