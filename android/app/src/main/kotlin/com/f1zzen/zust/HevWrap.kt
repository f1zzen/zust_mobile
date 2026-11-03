package com.f1zzen.zust

class HevWrapper {
  external fun startTunnel(configPath: String, fd: Int): Int
  external fun stopTunnel()

  companion object {
    init {
      System.loadLibrary("hev-socks5-tunnel")
      System.loadLibrary("zbridge")
    }
  }
}