import 'package:flutter/material.dart';
import '../main.dart';
import '../native.dart';
import '../theme.dart';
import '../widgets/power.dart';
import '../widgets/ui.dart';
import 'apps.dart';
import 'logs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool batteryWarn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // вернулись из настроек батареи - проверяем ещё раз
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _checkBattery();
  }

  Future<void> _checkBattery() async {
    try {
      final b = await zust.batteryOptimized();
      if (mounted) setState(() => batteryWarn = b);
    } catch (_) {}
  }

  void _toggle() {
    if (zust.state == TorState.off && !zust.pending) {
      zust.start(vpn: prefs.vpn, apps: prefs.apps);
    } else {
      zust.stop();
    }
  }

  void _busy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сначала отключите TOR'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([zust, prefs]),
      builder: (context, _) {
        final st = zust.pending && zust.state == TorState.off ? 1 : zust.state.index;
        final status = switch (st) {
          2 => prefs.vpn ? 'TOR работает · VPN' : 'TOR работает',
          1 => zust.progress > 0 ? 'Подключение · ${zust.progress}%' : 'Подключение…',
          _ => 'Выключено',
        };
        final hint = switch (st) {
          2 => prefs.vpn
              ? (prefs.apps.isEmpty ? 'Весь трафик идёт через TOR' : 'Через TOR: ${prefs.apps.length} прил.')
              : 'Прокси SOCKS5 · 127.0.0.1:9050',
          1 => zust.lastLog.isEmpty ? 'Запуск…' : zust.lastLog,
          _ => 'Нажмите, чтобы подключиться',
        };
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Text(
              t.mono ? 'z.ust' : 'Z.UST',
              textAlign: t.leftAligned ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                fontFamily: t.headingFont,
                fontSize: t.displaySize,
                fontWeight: t.headingWeight,
                color: t.onSurface,
                letterSpacing: t.m3e ? -.5 : 0,
              ),
            ),
            const SizedBox(height: 28),
            Center(child: PowerButton(state: st, progress: zust.progress, onTap: _toggle)),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: t.normal,
              child: Text(
                t.t(status),
                key: ValueKey(status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: t.headingFont,
                  fontSize: 22,
                  fontWeight: t.headingWeight,
                  color: st == 2 ? (t.mono ? t.onSurface : t.primary) : t.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => showLogs(context),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: t.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Режим'),
            Segmented(
              items: const ['Прокси', 'VPN'],
              selected: prefs.vpn ? 1 : 0,
              onChanged: (i) => st == 0 ? prefs.setVpn(i == 1) : _busy(context),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                prefs.vpn
                    ? 'Трафик приложений идёт через TOR. Сайты и DNS работают без настройки.'
                    : 'Только SOCKS5-прокси 127.0.0.1:9050 - укажите его в Telegram или браузере.',
                style: TextStyle(fontSize: 12, color: t.onSurfaceVariant),
              ),
            ),
            if (st == 1) ...[
              const SizedBox(height: 12),
              ZCard(
                child: Row(children: [
                  Icon(Icons.hourglass_top_rounded, color: t.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Подключение может занять 2–3 минуты, особенно в первый раз: Z.UST ищет рабочие мосты. '
                      'Это нормально - можно свернуть приложение, TOR продолжит подключаться.',
                      style: TextStyle(fontSize: 13, color: t.onSurface),
                    ),
                  ),
                ]),
              ),
            ],
            if (!prefs.vpn) ...[
              const SizedBox(height: 12),
              _Tile(
                icon: Icons.send_rounded,
                title: 'Добавить в Telegram',
                subtitle: 'Telegram сам предложит подключить прокси 127.0.0.1:9050. Работает, пока включён TOR.',
                onTap: () => zust.openLink('tg://socks?server=127.0.0.1&port=9050'),
              ),
            ],
            if (prefs.vpn) ...[
              const SizedBox(height: 12),
              _Tile(
                icon: Icons.apps_rounded,
                title: 'Приложения',
                subtitle: prefs.apps.isEmpty ? 'Все приложения' : 'Выбрано: ${prefs.apps.length}',
                onTap: () => st == 0 ? showAppPicker(context) : _busy(context),
              ),
            ],
            if (batteryWarn) ...[
              const SizedBox(height: 12),
              _Tile(
                icon: Icons.battery_alert_rounded,
                title: 'Ограничение батареи',
                subtitle: 'Система может остановить TOR в фоне. Нажмите, чтобы разрешить работу без ограничений.',
                onTap: zust.openBatterySettings,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ZCard(
        child: Row(children: [
          Icon(icon, color: t.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.t(title), style: TextStyle(fontSize: 15, color: t.onSurface, fontWeight: t.strongWeight)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: t.onSurfaceVariant)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: t.onSurfaceVariant),
        ]),
      ),
    );
  }
}
