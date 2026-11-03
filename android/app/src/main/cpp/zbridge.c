#include <jni.h>

extern int hev_socks5_tunnel_main(const char *config_path, int tun_fd);
extern void hev_socks5_tunnel_quit();

JNIEXPORT jint JNICALL
Java_com_f1zzen_zust_HevWrapper_startTunnel(JNIEnv *env, jobject thiz, jstring config_path, jint fd)
{
    const char *path = (*env)->GetStringUTFChars(env, config_path, 0);
    int result = hev_socks5_tunnel_main(path, fd);
    (*env)->ReleaseStringUTFChars(env, config_path, path);
    return result;
}

JNIEXPORT void JNICALL
Java_com_f1zzen_zust_HevWrapper_stopTunnel(JNIEnv *env, jobject thiz)
{
    hev_socks5_tunnel_quit();
}