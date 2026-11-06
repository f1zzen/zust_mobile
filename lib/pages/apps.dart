// Выбор приложений для VPN. Пустой выбор = все приложения.

import 'package:flutter/material.dart';
import '../main.dart';
import '../native.dart';
import '../theme.dart';
import '../widgets/ui.dart';

List<AppInfo>? _cache;

void showAppPicker(BuildContext context) {
  final t = ZThemeScope.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.classic ? const Color(0xFF0E0718) : t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusL))),
    builder: (_) => ZThemeScope(theme: t, child: const _Picker()),
  );
}

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final Set<String> chosen = prefs.apps.toSet();
  List<AppInfo>? apps = _cache;
  String query = '';

  @override
  void initState() {
    super.initState();
    if (apps == null) {
      zust.apps().then((a) {
        _cache = a;
        if (mounted) setState(() => apps = a);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final list = (apps ?? []).where((a) => query.isEmpty || a.name.toLowerCase().contains(query) || a.package.contains(query)).toList()
      // выбранные - сверху
      ..sort((a, b) => (chosen.contains(b.package) ? 1 : 0) - (chosen.contains(a.package) ? 1 : 0));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: t.outline, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.t('Приложения через TOR'),
                    style: TextStyle(fontFamily: t.headingFont, fontSize: 20, fontWeight: t.headingWeight, color: t.onSurface),
                  ),
                ),
                if (chosen.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(chosen.clear),
                    child: Text(t.t('Сбросить'), style: TextStyle(color: t.primary)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              chosen.isEmpty ? 'Ничего не выбрано - через TOR пойдут все приложения' : 'Выбрано: ${chosen.length}',
              style: TextStyle(fontSize: 12, color: t.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
              style: TextStyle(color: t.onSurface),
              decoration: InputDecoration(
                hintText: 'Поиск',
                prefixIcon: Icon(Icons.search_rounded, color: t.onSurfaceVariant),
                filled: true,
                fillColor: t.surfaceHigh,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.pillButtons ? 28 : t.radiusS),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: apps == null
                ? Center(child: CircularProgressIndicator(color: t.primary))
                : ListView.builder(
                    controller: scroll,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final on = chosen.contains(a.package);
                      return InkWell(
                        onTap: () => setState(() => on ? chosen.remove(a.package) : chosen.add(a.package)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Image.memory(a.icon, width: 40, height: 40, gaplessPlayback: true),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 15, color: t.onSurface),
                                    ),
                                    Text(
                                      a.package,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: t.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              ExcludeFocus(
                                child: ZSwitch(
                                  value: on,
                                  onChanged: (_) => setState(() => on ? chosen.remove(a.package) : chosen.add(a.package)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ZButton(
                'Готово',
                expand: true,
                onTap: () {
                  prefs.setApps(chosen.toList());
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
