// Главная кнопка включения - у каждой темы своя (как в Z.UST для ПК).
// state: 0 - выключено, 1 - подключение, 2 - работает; progress - 0..100.

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class PowerButton extends StatelessWidget {
  final int state;
  final int progress;
  final VoidCallback onTap;
  const PowerButton({super.key, required this.state, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    return switch (t.style) {
      ZStyle.m3e => _PowerM3E(state: state, onTap: onTap),
      ZStyle.warm => _PowerWarm(state: state, onTap: onTap),
      ZStyle.mono => _PowerMono(state: state, progress: progress, onTap: onTap),
      ZStyle.classic => _Reactor(state: state, progress: progress, onTap: onTap),
      ZStyle.lite => _PowerCircle(state: state, onTap: onTap),
    };
  }
}

/// Постоянно идущее время - для вращения, "дыхания" и мигания.
mixin _Ticking<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController clock =
      AnimationController(vsync: this, duration: const Duration(hours: 1));

  void syncClock(bool run) {
    if (run && !clock.isAnimating) {
      clock.repeat();
    } else if (!run && clock.isAnimating) {
      clock.stop();
    }
  }

  /// секунды с начала анимации
  double get secs => (clock.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

// ================= M3E: живая "печенька" =================

class _PowerM3E extends StatefulWidget {
  final int state;
  final VoidCallback onTap;
  const _PowerM3E({required this.state, required this.onTap});

  @override
  State<_PowerM3E> createState() => _PowerM3EState();
}

class _PowerM3EState extends State<_PowerM3E> with SingleTickerProviderStateMixin, _Ticking {
  bool down = false;
  double waveStart = -100;

  @override
  void didUpdateWidget(_PowerM3E old) {
    super.didUpdateWidget(old);
    // волна расходится в момент включения
    if (old.state != 2 && widget.state == 2) waveStart = secs;
  }

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    syncClock(t.motion);
    final on = widget.state == 2, busy = widget.state == 1;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapUp: (_) => setState(() => down = false),
      onTapCancel: () => setState(() => down = false),
      onTap: busy ? null : widget.onTap,
      child: SizedBox(
        width: 280,
        height: 280,
        child: TweenAnimationBuilder<double>(
          // amp: 0 - круг, 0.075 - "печенька"; пружинит при переключении
          tween: Tween(end: on ? .075 : 0),
          duration: t.slow,
          curve: const Cubic(.34, 1.56, .64, 1),
          builder: (_, amp, _) => AnimatedBuilder(
            animation: clock,
            builder: (_, _) {
              final s = secs;
              final wobble = busy && t.motion ? .07 + .05 * sin(s * 2 * pi / .7) : 0.0;
              final spin = !t.motion ? 0.0 : busy ? s * 2 * pi / 2.5 : on ? s * 2 * pi / 30 : 0.0;
              final breath = t.motion ? .5 + .5 * sin(s * 2 * pi / 3.2) : .5;
              final wave = t.motion ? ((s - waveStart) / 1.1).clamp(0.0, 1.0) : 1.0;
              return CustomPaint(
                painter: _CookiePainter(
                  t: t,
                  amp: busy ? wobble : amp,
                  spin: spin,
                  on: on,
                  busy: busy,
                  breath: breath,
                  wave: wave,
                  scale: down ? .9 : on ? 1 : .92,
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: down ? .85 : 1,
                    duration: t.fast,
                    child: Icon(Icons.power_settings_new_rounded,
                        size: 64, color: on ? t.onPrimary : t.onSurfaceVariant),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CookiePainter extends CustomPainter {
  final ZTheme t;
  final double amp, spin, breath, wave, scale;
  final bool on, busy;
  _CookiePainter({
    required this.t,
    required this.amp,
    required this.spin,
    required this.on,
    required this.busy,
    required this.breath,
    required this.wave,
    required this.scale,
  });

  Path shape(Offset c, double r, double amp, int lobes, double rot) {
    final p = Path();
    const n = 120;
    for (var i = 0; i <= n; i++) {
      final th = i / n * 2 * pi;
      final rr = r / (1 + amp) * (1 + amp * cos(lobes * th));
      final pt = c + Offset(cos(th + rot), sin(th + rot)) * rr;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final core = size.width * .38;
    // аура: мягкое "дыхание" света, пока всё работает
    if (on) {
      canvas.drawCircle(
        c,
        size.width / 2,
        Paint()
          ..shader = RadialGradient(colors: [
            t.primary.withValues(alpha: .30 + .15 * breath),
            t.primary.withValues(alpha: .08),
            t.primary.withValues(alpha: 0),
          ], stops: const [0, .55, 1])
              .createShader(Rect.fromCircle(center: c, radius: size.width / 2)),
      );
      // две волны от кнопки в момент включения
      for (final d in [0.0, .16]) {
        final w = ((wave - d) / (1 - d)).clamp(0.0, 1.0);
        if (w > 0 && w < 1) {
          canvas.drawCircle(
            c,
            core * (1 + .9 * w),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = t.primary.withValues(alpha: .55 * (1 - w)),
          );
        }
      }
      // ореол второго тона, вращается навстречу
      canvas.drawPath(shape(c, core * 1.22, .04, 12, -spin * .6), Paint()..color = t.primary.withValues(alpha: .2));
    }
    final body = shape(c, core * scale, amp, 9, spin);
    canvas.drawPath(body, Paint()..color = t.surfaceHigh);
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = t.outline);
    final fill = on ? 1.0 : busy ? .35 : 0.0;
    if (fill > 0) {
      final rect = Rect.fromCircle(center: c, radius: core);
      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brighter(t.primary, .18), t.primary, darker(t.primary, .28)].map((x) => x.withValues(alpha: fill)).toList(),
          ).createShader(rect),
      );
    }
    if (on) {
      final hc = c - Offset(0, core * .42);
      canvas.drawCircle(
          hc,
          core * .6,
          Paint()
            ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .18), Colors.white.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: hc, radius: core * .6)));
    }
  }

  @override
  bool shouldRepaint(_CookiePainter o) => true;
}

// ================= Тёплая: "физический" переключатель =================

class _PowerWarm extends StatelessWidget {
  final int state;
  final VoidCallback onTap;
  const _PowerWarm({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final on = state == 2, busy = state == 1;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: t.slow,
        curve: Curves.easeInOut,
        width: 196,
        height: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: on ? t.primary : t.surfaceHigh,
          borderRadius: BorderRadius.circular(52),
          border: on ? null : Border.all(color: t.outline),
        ),
        child: AnimatedAlign(
          duration: t.slow,
          curve: const Cubic(.22, 1.2, .36, 1),
          alignment: on || busy ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: on ? t.onPrimary : t.surface,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: t.primary),
                  )
                : Icon(Icons.power_settings_new_rounded, size: 32, color: on ? t.primary : t.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// ================= Моно: текстовая кнопка-терминал =================

class _PowerMono extends StatefulWidget {
  final int state, progress;
  final VoidCallback onTap;
  const _PowerMono({required this.state, required this.progress, required this.onTap});

  @override
  State<_PowerMono> createState() => _PowerMonoState();
}

class _PowerMonoState extends State<_PowerMono> with SingleTickerProviderStateMixin, _Ticking {
  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final on = widget.state == 2, busy = widget.state == 1;
    syncClock(t.motion && busy);
    return GestureDetector(
      onTap: busy ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: clock,
        builder: (_, _) {
          final caret = !t.motion || (secs % 1) < .5;
          return AnimatedContainer(
            duration: t.fast,
            width: 280,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? t.onSurface : t.surface,
              border: on ? null : Border.all(color: t.onSurface),
              borderRadius: BorderRadius.circular(t.radiusM),
            ),
            child: Text(
              busy ? 'подключение ${widget.progress}%${caret ? '_' : ' '}' : on ? '[ выключить ]' : '[ включить ]',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: on ? t.background : t.onSurface),
            ),
          );
        },
      ),
    );
  }
}

// ================= Лёгкая: простой круг =================

class _PowerCircle extends StatelessWidget {
  final int state;
  final VoidCallback onTap;
  const _PowerCircle({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    final on = state == 2;
    return GestureDetector(
      onTap: state == 1 ? null : onTap,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(color: on ? t.primary : t.surfaceHigh, shape: BoxShape.circle),
        child: state == 1
            ? Padding(padding: const EdgeInsets.all(64), child: CircularProgressIndicator(color: t.primary))
            : Icon(Icons.power_settings_new_rounded, size: 60, color: on ? t.onPrimary : t.onSurfaceVariant),
      ),
    );
  }
}

// ================= Классика: "реактор" из Z.UST 2 =================

class _Reactor extends StatefulWidget {
  final int state, progress;
  final VoidCallback onTap;
  const _Reactor({required this.state, required this.progress, required this.onTap});

  @override
  State<_Reactor> createState() => _ReactorState();
}

class _ReactorState extends State<_Reactor> with SingleTickerProviderStateMixin, _Ticking {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final t = ZThemeScope.of(context);
    syncClock(t.motion);
    final on = widget.state == 2, busy = widget.state == 1;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapUp: (_) => setState(() => down = false),
      onTapCancel: () => setState(() => down = false),
      onTap: busy ? null : widget.onTap,
      child: AnimatedScale(
        scale: down ? .97 : 1,
        duration: t.fast,
        child: Container(
          width: 320,
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: .03),
            border: Border.all(color: on ? t.primary.withValues(alpha: .45) : Colors.white.withValues(alpha: .1)),
            boxShadow: on ? [BoxShadow(color: t.primary.withValues(alpha: .25), blurRadius: 30)] : null,
          ),
          child: AnimatedBuilder(
            animation: clock,
            builder: (_, _) => CustomPaint(
              painter: _ReactorPainter(t, secs, on, busy),
              child: Stack(children: [
                Center(
                  child: busy
                      ? SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 2.5, color: t.primary))
                      : Text(on ? '✦' : '✕',
                          style: TextStyle(
                            fontSize: on ? 34 : 26,
                            color: t.primary,
                            shadows: on ? [Shadow(color: t.primary, blurRadius: 18)] : null,
                          )),
                ),
                if (busy)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: t.normal,
                      height: 2,
                      width: 320 * widget.progress / 100,
                      color: t.primary,
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  final ZTheme t;
  final double s;
  final bool on, busy;
  _ReactorPainter(this.t, this.s, this.on, this.busy);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final speed = busy ? 3.0 : on ? 1.0 : .25;
    for (final (i, ry) in [(0, .34), (1, .26)]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate((i == 0 ? 1 : -1) * s * speed * .6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: size.width * .92, height: size.height * ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = t.primary.withValues(alpha: on ? .55 : .25),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ReactorPainter o) => true;
}
