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
  Map<String, bool> comss = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBattery();
    _checkComss();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // вернулись из настроек батареи - проверяем ещё раз
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _checkBattery();
      _checkComss();
    }
  }

  Future<void> _checkComss() async {
    final c = await zust.comssStatus();
    if (mounted) setState(() => comss = c);
  }

  Future<void> _comss(BuildContext context) async {
    final on = comss['on'] == true;
    final r = await zust.comssSet(!on);
    if (r != 'manual') return _checkComss();
    if (!context.mounted) return;
    final t = ZThemeScope.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(on ? 'Выключить Comss DNS' : 'Включить Comss DNS', style: TextStyle(color: t.onSurface)),
        content: Text(
          on
              ? 'В открывшихся настройках найдите "Частный DNS" (обычно в "Сеть и интернет" или "Подключения" → '
                    '"Другие настройки") и выберите "Автоматически".'
              : 'Адрес dns.comss.one уже скопирован.\n\n'
                    'В открывшихся настройках найдите "Частный DNS" (обычно в "Сеть и интернет" или "Подключения" → '
                    '"Другие настройки"), выберите "Имя хоста поставщика" и вставьте адрес.',
          style: TextStyle(color: t.onSurface, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала отключите TOR'), duration: Duration(seconds: 2)));
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
          2 =>
            prefs.vpn
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
            Center(
              child: PowerButton(state: st, progress: zust.progress, onTap: _toggle),
            ),
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
            ZFocus(
              onTap: () => showLogs(context),
              radius: 8,
              child: GestureDetector(
                onTap: () => showLogs(context),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.onSurfaceVariant),
                ),
              ),
            ),
            if (prefs.traffic && st != 0) ...[
              const SizedBox(height: 10),
              Text(
                '↓ ${_size(zust.rx)}   ↑ ${_size(zust.tx)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
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
            if (zust.noVpn && prefs.vpn) ...[
              const SizedBox(height: 12),
              ZCard(
                child: Row(
                  children: [
                    Icon(Icons.tv_off_rounded, color: t.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Это устройство не разрешает приложениям включать VPN. Включите режим Прокси и укажите 127.0.0.1:9050 в нужном приложении.',
                        style: TextStyle(fontSize: 13, color: t.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (st == 1) ...[
              const SizedBox(height: 12),
              ZCard(
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: t.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Подключение может занять 2–3 минуты, особенно в первый раз: Z.UST ищет рабочие мосты. '
                        'Это нормально - можно свернуть приложение, TOR продолжит подключаться.',
                        style: TextStyle(fontSize: 13, color: t.onSurface),
                      ),
                    ),
                  ],
                ),
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
            if (comss['supported'] == true) ...[
              const SizedBox(height: 12),
              _Tile(
                icon: comss['on'] == true ? Icons.dns_rounded : Icons.dns_outlined,
                title: comss['on'] == true ? 'Comss DNS включён' : 'Comss DNS',
                subtitle: comss['on'] == true
                    ? 'ChatGPT, Claude, Copilot и другие открываются без TOR. Нажмите, чтобы выключить.'
                    : 'Открывает ChatGPT, Claude, Copilot и другие сервисы, недоступные из России, и убирает рекламу.',
                onTap: () => _comss(context),
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
    return ZFocus(
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ZCard(
          child: Row(
            children: [
              Icon(icon, color: t.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t(title),
                      style: TextStyle(fontSize: 15, color: t.onSurface, fontWeight: t.strongWeight),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: t.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _size(int b) {
  if (b < 1024) return '$b Б';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} КБ';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} МБ';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} ГБ';
}
