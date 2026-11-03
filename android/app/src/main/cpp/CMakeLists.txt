cmake_minimum_required(VERSION 3.22)
project("zust")

add_library(hev-socks5-tunnel SHARED IMPORTED)
set_target_properties(hev-socks5-tunnel PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libhev-socks5-tunnel.so)

add_library(zbridge SHARED zbridge.c)
target_link_libraries(zbridge hev-socks5-tunnel log)