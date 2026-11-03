package com.f1zzen.zust

import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.graphics.createBitmap
import androidx.core.graphics.scale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/**
 * Мост между интерфейсом (Dart) и сервисом. Сам TOR и VPN живут в [ZustService],
 * поэтому закрытие приложения их не останавливает.
 */
class MainActivity : FlutterActivity() {
    private val VPN_REQUEST = 7
    private var pending: Pair<String, List<String>>? = null
    private var eventListener: ((Map<String, Any>) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "com.f1zzen.zust/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                val l: (Map<String, Any>) -> Unit = { sink.success(it) }
                eventListener = l
                ZustService.listeners += l
                sink.success(ZustService.snapshot())
            }

            override fun onCancel(arguments: Any?) {
                eventListener?.let { ZustService.listeners -= it }
                eventListener = null
            }
        })

        MethodChannel(messenger, "com.f1zzen.zust/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val mode = call.argument<String>("mode") ?: "proxy"
                    val apps = call.argument<List<String>>("apps") ?: emptyList()
                    getSharedPreferences("zust", MODE_PRIVATE).edit()
                        .putString("mode", mode).putStringSet("apps", apps.toSet()).apply()
                    requestNotifications()
                    if (mode == "vpn") {
                        val consent = VpnService.prepare(this)
                        if (consent != null) {
                            pending = mode to apps
                            startActivityForResult(consent, VPN_REQUEST)
                            result.success("consent")
                            return@setMethodCallHandler
                        }
                    }
                    ZustService.start(this, mode, apps)
                    result.success("ok")
                }
                "stop" -> {
                    ZustService.stop(this)
                    result.success(null)
                }
                "status" -> result.success(ZustService.snapshot())
                "forgetBridges" -> {
                    Bridges.forget(java.io.File(filesDir, "tor"))
                    result.success(null)
                }
                "logs" -> result.success(synchronized(ZustService.logs) { ZustService.logs.toList() })
                "apps" -> thread {
                    val list = installedApps()
                    runOnUiThread { result.success(list) }
                }
                "batteryOptimized" -> {
                    val pm = getSystemService(PowerManager::class.java)
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatterySettings" -> {
                    // не блокирует запуск: на части прошивок проверка всегда "нет"
                    try {
                        @Suppress("BatteryLife")
                        startActivity(
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .setData(Uri.parse("package:$packageName"))
                        )
                    } catch (_: Exception) {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    .setData(Uri.fromParts("package", packageName, null))
                            )
                        } catch (_: Exception) {
                        }
                    }
                    result.success(null)
                }
                "openLink" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.startsWith("https://") || url.startsWith("tg://")) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        } catch (_: Exception) {
                            // Telegram не установлен - та же ссылка через t.me (откроется в браузере)
                            if (url.startsWith("tg://")) try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url.replace("tg://", "https://t.me/"))))
                            } catch (_: Exception) {
                            }
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("startActivityForResult - единственный способ получить согласие на VPN")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_REQUEST) return
        val p = pending ?: return
        pending = null
        if (resultCode == RESULT_OK) {
            ZustService.start(this, p.first, p.second)
        } else {
            ZustService.listeners.forEach { it(ZustService.snapshot() + mapOf("line" to "VPN не разрешён")) }
        }
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8)
        }
    }

    private fun installedApps(): List<Map<String, Any>> {
        val pm = packageManager
        return pm.getInstalledApplications(0)
            .filter {
                it.packageName != packageName &&
                    pm.getLaunchIntentForPackage(it.packageName) != null &&
                    ((it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                        (it.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0)
            }
            .map { app ->
                val icon = pm.getApplicationIcon(app)
                val bmp = if (icon is BitmapDrawable && icon.bitmap != null) icon.bitmap else {
                    val w = icon.intrinsicWidth.coerceIn(1, 192)
                    val h = icon.intrinsicHeight.coerceIn(1, 192)
                    createBitmap(w, h).also { b ->
                        val c = Canvas(b)
                        icon.setBounds(0, 0, c.width, c.height)
                        icon.draw(c)
                    }
                }
                // значки уменьшаем: 100+ приложений по 512px - это десятки мегабайт
                val small = if (bmp.width > 96) bmp.scale(96, 96) else bmp
                val out = ByteArrayOutputStream()
                small.compress(Bitmap.CompressFormat.PNG, 90, out)
                mapOf(
                    "name" to pm.getApplicationLabel(app).toString(),
                    "package" to app.packageName,
                    "icon" to out.toByteArray(),
                )
            }
            .sortedBy { (it["name"] as String).lowercase() }
    }
}
