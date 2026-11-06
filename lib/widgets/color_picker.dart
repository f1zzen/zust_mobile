import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';
import 'ui.dart';

/// Свой акцент: квадрат насыщенности и яркости, полоса оттенка, #hex. Цвет виден сразу,
/// "Отмена" возвращает прежний.
Future<void> showColorPicker(BuildContext context) {
  final before = prefs.theme.accent;
  return showDialog(
    context: context,
    builder: (_) => _PickerDialog(before: before),
  );
}

class _PickerDialog extends StatefulWidget {
  final Color before;
  const _PickerDialog({required this.before});

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  late HSVColor hsv = HSVColor.fromColor(widget.before);
  late final hex = TextEditingController(text: _hex(widget.before));

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _set(HSVColor v, {bool fromHex = false}) {
    setState(() => hsv = v);
    final c = v.toColor();
    if (!fromHex) hex.text = _hex(c);
    prefs.setTheme(prefs.theme.copyWith(accent: c));
  }

  void _hexEdited(String s) {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(s.trim());
    if (m != null) _set(HSVColor.fromColor(Color(0xFF000000 | int.parse(m[1]!, radix: 16))), fromHex: true);
  }

  // пульт или клавиатура: стрелки двигают ползунок
  KeyEventResult _keys(KeyEvent e, double dx, double dy) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    double x = 0, y = 0;
    if (k == LogicalKeyboardKey.arrowLeft) x = -1;
    if (k == LogicalKeyboardKey.arrowRight) x = 1;
    if (k == LogicalKeyboardKey.arrowUp) y = -1;
    if (k == LogicalKeyboardKey.arrowDown) y = 1;
    if (x == 0 && y == 0 || (dy == 0 && y != 0)) return KeyEventResult.ignored;
    if (dy == 0) {
      _set(hsv.withHue((hsv.hue + x * dx) % 360));
    } else {
      _set(hsv.withSaturation((hsv.saturation + x * dx).clamp(0, 1)).withValue((hsv.value - y * dy).clamp(0, 1)));
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final pure = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    return AlertDialog(
      backgroundColor: t.surface,
      title: Text('Свой цвет', style: TextStyle(color: t.onSurface)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pad(
              height: 180,
              onKey: (e) => _keys(e, .05, .05),
              onPos: (p) => _set(hsv.withSaturation(p.dx).withValue(1 - p.dy)),
              marker: Offset(hsv.saturation, 1 - hsv.value),
              radius: t.m3e ? 16 : 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white, pure])),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Pad(
              height: 22,
              onKey: (e) => _keys(e, 6, 0),
              onPos: (p) => _set(hsv.withHue(p.dx * 359.9)),
              marker: Offset(hsv.hue / 360, .5),
              radius: 11,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h % 360, 1, 1).toColor()]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: hsv.toColor(), borderRadius: BorderRadius.circular(t.m3e ? 14 : 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: hex,
                    onChanged: _hexEdited,
                    style: TextStyle(color: t.onSurface, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: t.outline),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            prefs.setTheme(prefs.theme.copyWith(accent: widget.before));
            Navigator.pop(context);
          },
          child: const Text('Отмена'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
      ],
    );
  }
}

/// Область, по которой водят пальцем; p - доли 0..1 по ширине и высоте.
class _Pad extends StatelessWidget {
  final double height, radius;
  final Offset marker;
  final ValueChanged<Offset> onPos;
  final KeyEventResult Function(KeyEvent) onKey;
  final Widget child;
  const _Pad({
    required this.height,
    required this.radius,
    required this.marker,
    required this.onPos,
    required this.onKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        void at(Offset p) => onPos(Offset((p.dx / w).clamp(0, 1), (p.dy / height).clamp(0, 1)));
        // Focus снаружи: стрелки от выделенного ZFocus всплывают сюда
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, e) => onKey(e),
          child: ZFocus(
            onTap: () {},
            radius: radius,
            child: GestureDetector(
              onPanDown: (d) => at(d.localPosition),
              onPanUpdate: (d) => at(d.localPosition),
              child: SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
                    ),
                    Positioned(
                      left: marker.dx * w - 9,
                      top: marker.dy * height - 9,
                      child: IgnorePointer(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: t.background.withValues(alpha: .5), blurRadius: 4)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
