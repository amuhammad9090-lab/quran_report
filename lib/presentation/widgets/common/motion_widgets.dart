import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'intro_animations.dart';

/// Komponen gerak & umpan balik yang dipakai lintas layar (tanpa package tambahan).

/// Getaran halus. Dibungkus try/catch karena tidak semua perangkat/platform mendukung.
class Haptics {
  Haptics._();

  /// Pilihan/ketukan ringan (mis. memilih Tuntas).
  static void selection() => _run(HapticFeedback.selectionClick);

  /// Aksi berhasil (mis. menyimpan laporan).
  static void success() => _run(HapticFeedback.lightImpact);

  /// Aksi penting/merusak (mis. menghapus).
  static void warning() => _run(HapticFeedback.mediumImpact);

  static void _run(Future<void> Function() f) {
    try {
      f();
    } catch (_) {}
  }
}

/// Item daftar yang muncul bergantian dari bawah. Hanya [maxAnimated] item pertama yang dianimasikan
/// supaya scroll panjang tidak terasa lambat atau berkedip.
class StaggerItem extends StatelessWidget {
  final int index;
  final Widget child;
  final int maxAnimated;

  const StaggerItem({super.key, required this.index, required this.child, this.maxAnimated = 10});

  @override
  Widget build(BuildContext context) {
    if (index >= maxAnimated) return child;
    return FadeSlideIn(
      delay: Duration(milliseconds: 45 * index),
      duration: const Duration(milliseconds: 450),
      offset: const Offset(0, 22),
      child: child,
    );
  }
}

/// Teks angka yang menghitung naik dari 0 ke nilainya. Bagian non-angka (awalan/akhiran seperti "%")
/// dipertahankan. Kalau teks bukan angka, ditampilkan apa adanya.
class CountUpText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;

  const CountUpText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.duration = const Duration(milliseconds: 900),
  });

  static final _re = RegExp(r'^(\D*)(\d{1,7})(\D*)$');

  @override
  Widget build(BuildContext context) {
    final m = _re.firstMatch(value);
    if (m == null || MediaQuery.of(context).disableAnimations) {
      return Text(value, style: style, textAlign: textAlign);
    }
    final prefix = m.group(1)!;
    final target = int.parse(m.group(2)!);
    final suffix = m.group(3)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${v.round()}$suffix', style: style, textAlign: textAlign),
    );
  }
}

/// Kotak abu berkilau untuk penanda "sedang memuat" (skeleton).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Membungkus [child] (susunan [SkeletonBox]) dengan kilau yang bergerak.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = rect.width * (_c.value * 2 - 0.5);
            return LinearGradient(
              colors: [
                Colors.transparent,
                cs.surface.withValues(alpha: 0.55),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromLTWH(dx - rect.width * 0.5, 0, rect.width, rect.height));
          },
          child: child,
        );
      },
    );
  }
}

/// Daftar kartu skeleton (mis. saat daftar laporan/kelola sedang dimuat).
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.itemHeight = 76,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                height: itemHeight,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const SkeletonBox(width: 44, height: 44, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 150, height: 13),
                          SizedBox(height: 8),
                          SkeletonBox(width: 90, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ikon yang melayang naik-turun pelan (dipakai di kondisi kosong).
class FloatingWidget extends StatefulWidget {
  final Widget child;
  final double amplitude;
  const FloatingWidget({super.key, required this.child, this.amplitude = 6});

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(offset: Offset(0, (t - 0.5) * 2 * widget.amplitude), child: child);
      },
    );
  }
}

/// Centang hijau besar yang muncul sebentar di tengah layar sebagai tanda "berhasil disimpan".
class SaveSuccessCheck {
  SaveSuccessCheck._();

  static void show(BuildContext context, {String? label}) {
    Haptics.success();
    if (MediaQuery.of(context).disableAnimations) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SaveCheckOverlay(label: label, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _SaveCheckOverlay extends StatefulWidget {
  final String? label;
  final VoidCallback onDone;
  const _SaveCheckOverlay({required this.onDone, this.label});

  @override
  State<_SaveCheckOverlay> createState() => _SaveCheckOverlayState();
}

class _SaveCheckOverlayState extends State<_SaveCheckOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Masuk (0-0.3): membesar membal; tahan; keluar (0.8-1): memudar.
            final enter = Curves.easeOutBack.transform((t / 0.3).clamp(0.0, 1.0));
            final fade = t > 0.8 ? 1 - (t - 0.8) / 0.2 : 1.0;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.4 + 0.6 * enter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5C46),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.circleCheck, color: Colors.white, size: 44),
                      if (widget.label != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
