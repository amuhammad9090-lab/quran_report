import 'dart:async';

import 'package:flutter/material.dart';

/// Animasi ringan untuk layar pembuka (Splash, Onboarding, Login). Hanya memakai animasi bawaan
/// Flutter, tanpa package tambahan. Semua menghormati pengaturan "hapus animasi" di perangkat.

/// Muncul dengan memudar + bergeser (dan opsional membesar) setelah [delay].
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Jarak geser awal; bergerak ke posisi asli saat animasi selesai.
  final Offset offset;
  final Curve curve;

  /// Kalau diisi (mis. 0.8), widget juga membesar dari skala ini ke 1.
  final double? scaleFrom;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.offset = const Offset(0, 18),
    this.curve = Curves.easeOutCubic,
    this.scaleFrom,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: widget.curve);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) {
        final v = _a.value;
        Widget w = child!;
        final s = widget.scaleFrom;
        if (s != null) w = Transform.scale(scale: s + (1 - s) * v, child: w);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(widget.offset.dx * (1 - v), widget.offset.dy * (1 - v)),
            child: w,
          ),
        );
      },
    );
  }
}

/// Cincin yang melebar dan memudar berulang di belakang [child] (efek "denyut" lembut).
class PulseRings extends StatefulWidget {
  final double size;
  final Color color;
  final int rings;
  final Widget? child;

  const PulseRings({super.key, required this.size, this.color = Colors.white, this.rings = 2, this.child});

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  bool _started = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    if (!still && !_started) {
      _started = true;
      _c.repeat();
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!still)
                for (var i = 0; i < widget.rings; i++)
                  Builder(builder: (context) {
                    final t = (_c.value + i / widget.rings) % 1.0;
                    return Opacity(
                      opacity: (1 - t) * 0.35,
                      child: Container(
                        width: widget.size * (0.55 + 0.45 * t),
                        height: widget.size * (0.55 + 0.45 * t),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.color, width: 2),
                        ),
                      ),
                    );
                  }),
              if (widget.child != null) widget.child!,
            ],
          );
        },
      ),
    );
  }
}

/// Transisi pindah layar dengan memudar (dipakai Splash -> Onboarding/Login/Home dst).
Route<T> fadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 500)}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
  );
}
