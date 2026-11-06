import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'about.dart';
import 'logs.dart';
import '../widgets/color_picker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Text(
            t.t('Настройки'),
            textAlign: t.leftAligned ? TextAlign.left : TextAlign.center,
            style: TextStyle(fontFamily: t.headingFont, fontSize: t.displaySize * .8, fontWeight: t.headingWeight, color: t.onSurface),
          ),
          const SizedBox(height: 12),
          const SectionTitle('Тема'),
          _StyleGrid(),
          if (!t.mono && !t.classic) ...[
            const SectionTitle('Цвет'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in accents)
                  ZFocus(
                    onTap: () => prefs.setTheme(prefs.theme.copyWith(accent: c)),
                    radius: 22,
                    child: GestureDetector(
                      onTap: () => prefs.setTheme(prefs.theme.copyWith(accent: c)),
                      child: AnimatedContainer(
                        duration: t.normal,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(t.m3e && c.toARGB32() == t.accent.toARGB32() ? 14 : 22),
                          border: c.toARGB32() == t.accent.toARGB32() ? Border.all(color: t.onSurface, width: 3) : null,
                        ),
                      ),
                    ),
                  ),
                _OwnColor(),
              ],
            ),
          ],
          const SectionTitle('Вид'),
          ZCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SettingRow(
                  title: 'Тёмная тема',
                  hint: t.classic ? 'В "Классике" всегда тёмная' : null,
                  value: t.dark,
                  onChanged: t.classic ? null : (v) => prefs.setTheme(prefs.theme.copyWith(dark: v)),
                ),
                SettingRow(
                  title: 'Анимации',
                  hint: t.lite ? 'В "Лёгкой" анимаций нет' : 'Выключите, если телефон тормозит',
                  value: t.motion,
                  divider: true,
                  onChanged: t.lite ? null : (v) => prefs.setTheme(prefs.theme.copyWith(animations: v)),
                ),
                SettingRow(
                  title: 'Показывать трафик',
                  hint: 'Сколько TOR скачал и отправил с момента включения',
                  value: prefs.traffic,
                  divider: true,
                  onChanged: prefs.setTraffic,
                ),
                if (!prefs.tv)
                  NavRow(
                    title: 'Кнопка в шторке',
                    hint: 'Включать Z.UST рядом с фонариком, не открывая приложение',
                    divider: true,
                    onTap: () => _addTile(context),
                  ),
              ],
            ),
          ),
          const SectionTitle('Работа в фоне'),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Z.UST держит TOR в фоне с уведомлением. Если система всё равно его закрывает, '
                  'снимите ограничения батареи для Z.UST.',
                  style: TextStyle(fontSize: 13, color: t.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ZButton('Батарея', icon: Icons.battery_charging_full_rounded, kind: BtnKind.tonal, onTap: zust.openBatterySettings),
                    ZButton('Журнал', icon: Icons.receipt_long_rounded, kind: BtnKind.outline, onTap: () => showLogs(context)),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Мосты'),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Z.UST запоминает рабочие мосты и подключается через них. Если подключение стало '
                  'долгим или не проходит - забудьте их, при следующем запуске Z.UST найдёт новые.',
                  style: TextStyle(fontSize: 13, color: t.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ZButton(
                  'Забыть сохранённые мосты',
                  icon: Icons.restart_alt_rounded,
                  kind: BtnKind.tonal,
                  onTap: () async {
                    await zust.forgetBridges();
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Мосты забыты - при следующем запуске Z.UST найдёт новые')));
                    }
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('Сообщество'),
          ZCard(
            padding: EdgeInsets.zero,
            child: ListenableBuilder(
              listenable: info,
              builder: (context, _) => Column(
                children: [
                  NavRow(
                    title: 'Новости',
                    hint: info.newsTitle.isEmpty ? 'Новостей пока нет' : info.newsTitle,
                    onTap: () => showAbout(context, 0),
                  ),
                  NavRow(title: 'Спонсоры', hint: 'Те, кто поддержал Z.UST на Boosty', divider: true, onTap: () => showAbout(context, 1)),
                  NavRow(title: 'Сообщество', hint: 'Те, кто помог проекту', divider: true, onTap: () => showAbout(context, 2)),
                ],
              ),
            ),
          ),
          const SectionTitle('О приложении'),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Z.UST',
                      style: TextStyle(fontFamily: t.headingFont, fontSize: 18, fontWeight: t.headingWeight, color: t.onSurface),
                    ),
                    const SizedBox(width: 8),
                    // версия Android-приложения ведётся отдельно от версии для ПК
                    Text('для Android · v1.0.0', style: TextStyle(fontSize: 13, color: t.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'TOR с мостами для Android. Свежие мосты Z.UST находит сам и запоминает рабочие.',
                  style: TextStyle(fontSize: 13, color: t.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ZButton(
                  'GitHub',
                  icon: Icons.code_rounded,
                  kind: BtnKind.outline,
                  onTap: () => zust.openLink('https://github.com/f1zzen/zust'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    const hints = [
      'Google-like дизайн. На любителя..',
      'Приятный стиль. Никогда не узнаете откуда ;)',
      'imput please don\'t sue me /j',
      'v2 стиль. Как обычно.',
      'Для слабых телефонов',
    ];
    return Column(
      children: [
        for (var i = 0; i < ZStyle.values.length; i++) ...[
          ZFocus(
            onTap: () => prefs.setTheme(prefs.theme.copyWith(style: ZStyle.values[i])),
            child: GestureDetector(
              onTap: () => prefs.setTheme(prefs.theme.copyWith(style: ZStyle.values[i])),
              child: AnimatedContainer(
                duration: t.normal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: t.style.index == i ? t.primaryContainer : (t.m3e ? t.surfaceHigh : t.surface),
                  borderRadius: BorderRadius.circular(t.radiusM),
                  border: t.style.index == i
                      ? Border.all(color: t.mono ? t.onSurface : t.primary, width: 1.5)
                      : (t.cardBorder || t.mono ? Border.all(color: t.outline) : null),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            styleNames[i],
                            style: TextStyle(
                              fontFamily: ['GoogleSans', 'Lora', 'IBMPlexMono', 'Onest', 'Onest'][i],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: t.style.index == i ? t.onPrimaryContainer : t.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hints[i],
                            style: TextStyle(fontSize: 12, color: t.style.index == i ? t.onPrimaryContainer : t.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (t.style.index == i) Icon(Icons.check_circle_rounded, color: t.mono ? t.onSurface : t.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

Future<void> _addTile(BuildContext context) async {
  // Android 13+ спрашивает сам; на старых и на части прошивок - вручную
  if (await zust.addTile() == 'asked' || !context.mounted) return;
  final t = ZThemeScope.of(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: t.surface,
      title: Text('Кнопка в шторке', style: TextStyle(color: t.onSurface)),
      content: Text(
        '1. Опустите шторку полностью (двумя пальцами или дважды).\n'
        '2. Нажмите карандаш или "Изменить" (на Xiaomi - значок в углу пункта управления, '
        'на Samsung - три точки → "Изменить кнопки").\n'
        '3. Найдите Z.UST и перетащите его к остальным кнопкам.\n\n'
        'Кнопка включает TOR в последнем выбранном режиме. Если нужно разрешение на VPN, откроется Z.UST.',
        style: TextStyle(color: t.onSurface, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
    ),
  );
}

/// Радужный кружок после готовых цветов: свой акцент. Внутри - текущий, если он не из списка.
class _OwnColor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final own = !accents.any((c) => c.toARGB32() == t.accent.toARGB32());
    return ZFocus(
      onTap: () => showColorPicker(context),
      radius: 22,
      child: GestureDetector(
        onTap: () => showColorPicker(context),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h % 360, 1, 1).toColor()]),
            border: own ? Border.all(color: t.onSurface, width: 3) : null,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, color: own ? t.accent : t.surface),
          ),
        ),
      ),
    );
  }
}
