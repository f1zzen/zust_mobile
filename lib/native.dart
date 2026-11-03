// Связь с ZustService (Kotlin): TOR и VPN живут в сервисе, интерфейс только показывает состояние.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum TorState { off, connecting, on }

class AppInfo {
  final String name;
  final String package;
  final Uint8List icon;
  AppInfo(this.name, this.package, this.icon);
}

class Zust extends ChangeNotifier {
  static const _method = MethodChannel('com.f1zzen.zust/native');
  static const _events = EventChannel('com.f1zzen.zust/events');

  TorState state = TorState.off;
  int progress = 0;
  String lastLog = '';
  final List<String> logs = [];
  StreamSubscription? _sub;

  /// Нажали "включить", но сервис ещё не ответил (или ждём согласия на VPN).
  bool pending = false;

  Future<void> init() async {
    try {
      final old = await _method.invokeListMethod<String>('logs');
      if (old != null) logs.addAll(old);
    } catch (_) {}
    _sub = _events.receiveBroadcastStream().listen((e) {
      final m = Map<String, dynamic>.from(e as Map);
      state = TorState.values[(m['state'] as int).clamp(0, 2)];
      progress = m['progress'] as int;
      final line = m['line'] as String?;
      if (line != null) {
        logs.add(line);
        if (logs.length > 400) logs.removeRange(0, logs.length - 400);
        lastLog = line;
        if (line == 'VPN не разрешён') pending = false;
      } else if ((m['log'] as String?)?.isNotEmpty ?? false) {
        lastLog = m['log'] as String;
      }
      if (state != TorState.off) pending = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> start({required bool vpn, required List<String> apps}) async {
    pending = true;
    notifyListeners();
    final r = await _method.invokeMethod<String>('start', {'mode': vpn ? 'vpn' : 'proxy', 'apps': apps});
    // ждём окно согласия на VPN дольше; если сервис так и не ответил - снимаем "ожидание"
    Future.delayed(Duration(seconds: r == 'consent' ? 60 : 10), () {
      if (pending && state == TorState.off) {
        pending = false;
        notifyListeners();
      }
    });
  }

  Future<void> stop() async {
    pending = false;
    await _method.invokeMethod('stop');
  }

  Future<List<AppInfo>> apps() async {
    final list = await _method.invokeListMethod<Map>('apps') ?? [];
    return list
        .map((m) => AppInfo(m['name'] as String, m['package'] as String, m['icon'] as Uint8List))
        .toList();
  }

  Future<bool> batteryOptimized() async => await _method.invokeMethod<bool>('batteryOptimized') ?? false;
  Future<void> openBatterySettings() => _method.invokeMethod('openBatterySettings');
  Future<void> forgetBridges() => _method.invokeMethod('forgetBridges');
  Future<void> openLink(String url) => _method.invokeMethod('openLink', {'url': url});
}
