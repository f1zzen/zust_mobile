// Общие элементы интерфейса. Каждый подстраивается под текущую тему (ZThemeScope).

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class ZCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const ZCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return AnimatedContainer(
      duration: t.normal,
      padding: padding,
      decoration: BoxDecoration(
        color: t.m3e ? t.surfaceHigh : t.surface,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: t.cardBorder || t.mono ? Border.all(color: t.outline) : null,
      ),
      child: child,
    );
  }
}

enum BtnKind { filled, tonal, outline, text }

class ZButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final BtnKind kind;
  final VoidCallback? onTap;
  final bool expand;
  const ZButton(this.text, {super.key, this.icon, this.kind = BtnKind.filled, this.onTap, this.expand = false});

  @override
  State<ZButton> createState() => _ZButtonState();
}

class _ZButtonState extends State<ZButton> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final enabled = widget.onTap != null;
    final k = widget.kind;
    final bg = !enabled && (k == BtnKind.filled || k == BtnKind.tonal)
        ? t.surfaceHigh
        : k == BtnKind.filled
            ? t.primary
            : k == BtnKind.tonal
                ? t.primaryContainer
                : Colors.transparent;
    final fg = !enabled
        ? t.onSurfaceVariant
        : k == BtnKind.filled
            ? t.onPrimary
            : k == BtnKind.tonal
                ? t.onPrimaryContainer
                : (t.mono || t.warm)
                    ? t.onSurface
                    : t.primary;
    final h = t.m3e ? 52.0 : 46.0;
    // M3E: при нажатии таблетка "сплющивается" в скруглённый квадрат
    final radius = t.pillButtons ? (down && t.m3e && t.motion ? t.radiusS : h / 2) : t.radiusS;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => down = true) : null,
      onTapUp: enabled ? (_) => setState(() => down = false) : null,
      onTapCancel: () => setState(() => down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: down && (t.mono || t.warm) && t.motion ? .97 : 1,
        duration: t.fast,
        child: AnimatedContainer(
          duration: t.normal,
          curve: const Cubic(.34, 1.56, .64, 1),
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: down && enabled ? Color.lerp(bg == Colors.transparent ? fg.withValues(alpha: 0) : bg, fg, .12) : bg,
            borderRadius: BorderRadius.circular(radius),
            border: k == BtnKind.outline ? Border.all(color: t.outline.withValues(alpha: .4)) : null,
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  t.t(widget.text),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 15, fontWeight: t.mono ? FontWeight.w500 : t.strongWeight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    if (t.classic) return Separator(text);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
      child: Text(
        t.mono ? text.toUpperCase() : text,
        style: TextStyle(
          color: t.mono || t.warm ? t.onSurfaceVariant : t.primary,
          fontSize: t.mono ? 12 : 13,
          fontWeight: FontWeight.w700,
          letterSpacing: t.mono ? 1 : .3,
        ),
      ),
    );
  }
}

/// Разделитель "- ТЕКСТ -" из Z.UST 2 (тема "Классика").
class Separator extends StatelessWidget {
  final String text;
  const Separator(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: .08)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text.toUpperCase(),
              style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Colors.white.withValues(alpha: .35))),
        ),
        line,
      ]),
    );
  }
}

/// Выбор одного варианта из нескольких (режим, тема).
class Segmented extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;
  const Segmented({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final r = t.pillButtons ? 24.0 : t.radiusS;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: t.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: t.normal,
                    decoration: BoxDecoration(
                      color: i == selected ? (t.mono ? t.onSurface : t.primaryContainer) : Colors.transparent,
                      border: i > 0 ? Border(left: BorderSide(color: t.outline)) : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (i == selected && !t.mono) ...[
                        Icon(Icons.check_rounded, size: 16, color: t.onPrimaryContainer),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          t.t(items[i]),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == selected ? t.strongWeight : FontWeight.w400,
                            color: i == selected ? (t.mono ? t.background : t.onPrimaryContainer) : t.onSurface,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ZSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const ZSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final w = t.mono ? 46.0 : 52.0, h = t.mono ? 24.0 : 32.0;
    final r = t.mono ? 0.0 : h / 2;
    final knob = value ? h - 8 : (t.m3e ? h - 16 : h - 8);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: t.normal,
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: value ? t.primary : t.surfaceHigh,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: value ? t.primary : t.onSurfaceVariant, width: 2),
        ),
        child: AnimatedAlign(
          duration: t.normal,
          curve: const Cubic(.34, 1.4, .64, 1),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: t.normal,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              color: value ? t.onPrimary : t.onSurfaceVariant,
              borderRadius: BorderRadius.circular(t.mono ? 0 : knob / 2),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool divider;
  const SettingRow({super.key, required this.title, this.hint, required this.value, this.onChanged, this.divider = false});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: t.outline)) : null),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.t(title), style: TextStyle(fontSize: 15, color: t.onSurface)),
              if (hint != null) ...[
                const SizedBox(height: 3),
                Text(hint!, style: TextStyle(fontSize: 12, color: t.onSurfaceVariant)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          ZSwitch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}

/// Звёздное небо "Классики": три слоя с разной скоростью, как в Z.UST 2.
class StarsBackground extends StatefulWidget {
  final bool animate;
  const StarsBackground({super.key, this.animate = true});

  @override
  State<StarsBackground> createState() => _StarsBackgroundState();
}

class _StarsBackgroundState extends State<StarsBackground> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    if (widget.animate) c.repeat();
  }

  @override
  void didUpdateWidget(StarsBackground old) {
    super.didUpdateWidget(old);
    widget.animate ? (c.isAnimating ? null : c.repeat()) : c.stop();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _StarsPainter(c), size: Size.infinite),
      );
}

class _StarsPainter extends CustomPainter {
  final Animation<double> a;
  _StarsPainter(this.a) : super(repaint: a);

  static final _layers = [
    for (final (count, size, speed, seed) in [(70, 1.0, 100.0, 1), (32, 1.6, 50.0, 2), (14, 2.4, 33.0, 3)])
      (size, speed, [for (var i = 0, r = Random(seed); i < count; i++) Offset(r.nextDouble(), r.nextDouble())]),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    // фон: тёмный с фиолетовым свечением снизу
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 1.1),
          radius: 1.1,
          colors: const [Color(0xFF180A30), Color(0xFF05010A)],
        ).createShader(Offset.zero & s),
    );
    final secs = a.value * 60;
    final p = Paint()..color = Colors.white.withValues(alpha: .8);
    for (final (size, speed, stars) in _layers) {
      final shift = (secs * speed) % s.height;
      for (final o in stars) {
        final y = (o.dy * s.height - shift) % s.height;
        canvas.drawCircle(Offset(o.dx * s.width, y), size / 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

/// Строка, которая открывает окно или шторку.
class NavRow extends StatelessWidget {
  final String title;
  final String? hint;
  final bool divider;
  final VoidCallback onTap;
  const NavRow({super.key, required this.title, this.hint, this.divider = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: t.outline)) : null),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.t(title), style: TextStyle(fontSize: 15, color: t.onSurface)),
              if (hint != null) ...[
                const SizedBox(height: 3),
                Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.onSurfaceVariant)),
              ],
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: t.onSurfaceVariant),
        ]),
      ),
    );
  }
}
