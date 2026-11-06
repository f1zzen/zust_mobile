package com.f1zzen.zust

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Кнопка Z.UST в шторке (рядом с фонариком). Включает TOR в последнем выбранном режиме.
 * Если нужно согласие на VPN или система не даёт запуститься из шторки - открывает приложение.
 */
class ZustTile : TileService() {
    private val listener: (Map<String, Any>) -> Unit = { update() }

    override fun onStartListening() {
        ZustService.listeners += listener
        update()
    }

    override fun onStopListening() {
        ZustService.listeners -= listener
    }

    override fun onClick() {
        if (ZustService.state != 0) {
            ZustService.stop(this)
            return
        }
        val p = getSharedPreferences("zust", MODE_PRIVATE)
        val mode = p.getString("mode", "proxy") ?: "proxy"
        val apps = p.getStringSet("apps", emptySet())?.toList() ?: emptyList()
        if (mode == "vpn" && VpnService.prepare(this) != null) {
            openApp()
            return
        }
        try {
            ZustService.start(this, mode, apps)
        } catch (_: Exception) {
            // часть прошивок (MIUI, HyperOS, ColorOS) не даёт запускать сервис из шторки
            openApp()
        }
    }

    private fun openApp() {
        val i = Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_START, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 2, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(i)
        }
    }

    private fun update() {
        val t = qsTile ?: return
        t.state = if (ZustService.state == 0) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        t.label = "Z.UST"
        if (Build.VERSION.SDK_INT >= 29) {
            t.subtitle = when (ZustService.state) {
                2 -> if (ZustService.mode == "vpn") "TOR · VPN" else "TOR · прокси"
                1 -> "Подключение ${ZustService.progress}%"
                else -> "Выключен"
            }
        }
        t.updateTile()
    }
}
