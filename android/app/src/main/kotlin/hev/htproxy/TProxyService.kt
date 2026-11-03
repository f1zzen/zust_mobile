package hev.htproxy

/**
 * Заглушка: libhev-socks5-tunnel при загрузке (JNI_OnLoad) ищет этот класс и
 * регистрирует в нём свои функции. Без него библиотека не загрузится.
 * Сам туннель запускается через HevWrapper (zbridge.c) из ZustService.
 */
@Suppress("unused")
class TProxyService {
    companion object {
        @JvmStatic private external fun TProxyStartService(configPath: String, fd: Int)
        @JvmStatic private external fun TProxyStopService()
        @JvmStatic private external fun TProxyGetStats(): LongArray
    }
}
