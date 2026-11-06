package com.f1zzen.zust

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.provider.Settings

/**
 * Comss.one DNS через системный "Частный DNS" (Android 9+): открывает ChatGPT, Claude и др.
 * Включить сам Z.UST может только с правом WRITE_SECURE_SETTINGS (выдаётся через adb),
 * иначе открываем настройки и копируем адрес.
 */
object Comss {
    const val HOST = "dns.comss.one"

    fun supported() = Build.VERSION.SDK_INT >= 28

    fun canWrite(ctx: Context) =
        ctx.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED

    fun enabled(ctx: Context): Boolean {
        if (!supported()) return false
        val spec = try {
            if (Settings.Global.getString(ctx.contentResolver, "private_dns_mode") == "hostname")
                Settings.Global.getString(ctx.contentResolver, "private_dns_specifier")
            else ""
        } catch (_: Exception) {
            null
        }
        if (spec != null) return spec == HOST
        val cm = ctx.getSystemService(ConnectivityManager::class.java)
        return cm.getLinkProperties(cm.activeNetwork)?.privateDnsServerName == HOST
    }

    /** "on" / "off" - переключили сами, "manual" - открыты настройки. */
    fun set(ctx: Context, on: Boolean): String {
        if (canWrite(ctx)) {
            val r = ctx.contentResolver
            val p = ctx.getSharedPreferences("zust", Context.MODE_PRIVATE)
            if (on) {
                // прежний DNS вернём при выключении
                if (!enabled(ctx)) {
                    p.edit()
                        .putString("dns_mode", Settings.Global.getString(r, "private_dns_mode") ?: "opportunistic")
                        .putString("dns_spec", Settings.Global.getString(r, "private_dns_specifier") ?: "")
                        .apply()
                }
                Settings.Global.putString(r, "private_dns_specifier", HOST)
                Settings.Global.putString(r, "private_dns_mode", "hostname")
                return "on"
            }
            Settings.Global.putString(r, "private_dns_specifier", p.getString("dns_spec", "") ?: "")
            Settings.Global.putString(r, "private_dns_mode", p.getString("dns_mode", "opportunistic") ?: "opportunistic")
            return "off"
        }
        if (on) {
            ctx.getSystemService(ClipboardManager::class.java)
                .setPrimaryClip(ClipData.newPlainText("Comss DNS", HOST))
        }
        for (action in listOf(Settings.ACTION_WIRELESS_SETTINGS, Settings.ACTION_SETTINGS)) {
            try {
                ctx.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                break
            } catch (_: Exception) {
            }
        }
        return "manual"
    }
}
