import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'info.dart';
import 'native.dart';
import 'pages/about.dart';
import 'pages/home.dart';
import 'pages/settings.dart';
import 'theme.dart';
import 'widgets/ui.dart';

final zust = Zust();
final prefs = Prefs();
final info = Info();

/// Настройки интерфейса и режима, хранятся между запусками.
class Prefs extends ChangeNotifier {
  late SharedPreferences _p;
  ZTheme theme = const ZTheme();
  bool vpn = false;
  List<String> apps = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    theme = ZTheme(
      style: ZStyle.values[(_p.getInt('style') ?? ZStyle.classic.index).clamp(0, ZStyle.values.length - 1)],
      darkPref: _p.getBool('dark') ?? true,
      animations: _p.getBool('animations') ?? true,
      accent: Color(_p.getInt('accent') ?? 0xFF8E6CEF),
    );
    vpn = _p.getBool('vpn') ?? false;
    apps = _p.getStringList('apps') ?? [];
  }

  void setTheme(ZTheme t) {
    theme = t;
    // пока тему не меняли, не запоминаем: иначе застынет текущая тема по умолчанию
    if (_p.containsKey('style') || t.style != ZStyle.classic) _p.setInt('style', t.style.index);
    _p.setBool('dark', t.darkPref);
    _p.setBool('animations', t.animations);
    _p.setInt('accent', t.accent.toARGB32());
    notifyListeners();
  }

  String get newsSeen => _p.getString('news_seen') ?? '';
  void setNewsSeen(String id) => _p.setString('news_seen', id);

  void setVpn(bool v) {
    vpn = v;
    _p.setBool('vpn', v);
    notifyListeners();
  }

  void setApps(List<String> a) {
    apps = a;
    _p.setStringList('apps', a);
    notifyListeners();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await prefs.load();
  await zust.init();
  runApp(const ZustApp());
}

class ZustApp extends StatelessWidget {
  const ZustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final t = prefs.theme;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: t.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness: t.dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Z.UST',
          debugShowCheckedModeBanner: false,
          theme: t.material,
          builder: (context, child) => ZThemeScope(theme: t, child: child!),
          home: const Shell(),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int page = 0;

  @override
  void initState() {
    super.initState();
    // новую новость показываем один раз
    info.load().then((_) {
      if (mounted && info.newsId.isNotEmpty && info.newsId != prefs.newsSeen) showAbout(context, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return Scaffold(
      backgroundColor: t.background,
      extendBody: true,
      body: Stack(children: [
        if (t.classic) Positioned.fill(child: StarsBackground(animate: t.motion)),
        SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: t.normal,
            switchInCurve: Curves.easeOutCubic,
            // уходящая страница исчезает сразу - без наложения двух страниц друг на друга
            layoutBuilder: (current, previous) => current ?? const SizedBox(),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(page), child: page == 0 ? const HomePage() : const SettingsPage()),
          ),
        ),
      ]),
      bottomNavigationBar: _NavBar(page: page, onTap: (i) => setState(() => page = i)),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int page;
  final ValueChanged<int> onTap;
  const _NavBar({required this.page, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    const items = [(Icons.power_settings_new_rounded, 'Главная'), (Icons.tune_rounded, 'Настройки')];
    // M3E и Классика - плавающая "таблетка", остальные - обычная панель снизу
    final floating = t.m3e || t.classic;
    final bar = Container(
      height: 68,
      decoration: BoxDecoration(
        color: floating ? (t.classic ? const Color(0xFF140A24).withValues(alpha: .9) : t.surfaceHigh) : t.surface,
        borderRadius: floating ? BorderRadius.circular(34) : null,
        border: floating
            ? (t.classic ? Border.all(color: Colors.white.withValues(alpha: .1)) : null)
            : Border(top: BorderSide(color: t.outline)),
      ),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AnimatedContainer(
                  duration: t.normal,
                  curve: const Cubic(.34, 1.56, .64, 1),
                  width: i == page ? 60 : 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: i == page && !t.mono ? t.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(t.mono ? 0 : 15),
                    border: i == page && t.mono ? Border(bottom: BorderSide(color: t.onSurface, width: 2)) : null,
                  ),
                  child: Icon(items[i].$1, size: 22, color: i == page ? (t.mono ? t.onSurface : t.onPrimaryContainer) : t.onSurfaceVariant),
                ),
                const SizedBox(height: 3),
                Text(t.t(items[i].$2),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == page ? t.strongWeight : FontWeight.w400,
                      color: i == page ? t.onSurface : t.onSurfaceVariant,
                    )),
              ]),
            ),
          ),
      ]),
    );
    if (!floating) {
      // фон панели продолжается под системной полоской жестов
      return Container(color: t.surface, child: SafeArea(top: false, child: bar));
    }
    // под "таблеткой" - плавное затемнение, чтобы список не просвечивал рядом с ней
    final base = t.classic ? const Color(0xFF05010A) : t.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base.withValues(alpha: 0), base.withValues(alpha: .92), base],
          stops: const [0, .45, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(40, 24, 40, 12), child: bar),
      ),
    );
  }
}
