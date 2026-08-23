import 'package:flutter/material.dart';

/// Tombol "+" bulat di pojok kanan bawah tab Laporan. Ditekan sekali,
/// nyembul ke atas dua tombol mini: "Buat Folder" & "Buat Laporan" (dengan
/// label pill di sampingnya), lalu ikonnya berputar jadi silang. Ditekan
/// lagi (atau salah satu aksi dipilih) buat nutup lagi.
class SpeedDialFab extends StatefulWidget {
  final VoidCallback onBuatFolder;
  final VoidCallback onBuatLaporan;

  const SpeedDialFab({
    super.key,
    required this.onBuatFolder,
    required this.onBuatLaporan,
  });

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_ctrl.status == AnimationStatus.dismissed) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _pick(VoidCallback action) {
    _ctrl.reverse();
    action();
  }

  /// Progres animasi untuk item ke-[index] dari [count] item, dibuat
  /// staggered (item paling bawah/dekat FAB utama duluan muncul).
  double _progress(int index, int count) {
    final delay = index * 0.12;
    final t = ((_ctrl.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => _MiniAction(
            progress: _progress(1, 2),
            icon: Icons.create_new_folder_rounded,
            label: 'Buat Folder',
            background: cs.secondaryContainer,
            foreground: cs.onSecondaryContainer,
            onTap: () => _pick(widget.onBuatFolder),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => _MiniAction(
            progress: _progress(0, 2),
            icon: Icons.note_add_rounded,
            label: 'Buat Laporan',
            background: cs.primaryContainer,
            foreground: cs.onPrimaryContainer,
            onTap: () => _pick(widget.onBuatLaporan),
          ),
        ),
        const SizedBox(height: 14),
        FloatingActionButton(
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Transform.rotate(
              angle: _ctrl.value * 0.78539816339, // 45 derajat pas kebuka
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final double progress; // 0 = ketutup/hilang, 1 = kebuka penuh
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _MiniAction({
    required this.progress,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: progress < 0.6,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Theme.of(context).cardTheme.color,
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: background,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: foreground, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
