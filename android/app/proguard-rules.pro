# Классы, которые вызываются только из нативного кода - R8 не должен их удалять или переименовывать.
# libhev-socks5-tunnel при загрузке ищет hev/htproxy/TProxyService и регистрирует в нём функции.
-keep class hev.htproxy.TProxyService { *; }
# zbridge.c: Java_com_f1zzen_zust_HevWrapper_startTunnel / stopTunnel
-keep class com.f1zzen.zust.HevWrapper { *; }
-keepclasseswithmembernames class * { native <methods>; }
