import 'package:flutter/material.dart';

/// Breakpoint lebar layar, mengikuti konvensi Material 3 window size class
/// (disederhanakan jadi 2 kelas yang relevan buat app ini: HP vs
/// tablet-ke-atas). Dipakai di [MainShell] buat milih NavigationBar
/// (bottom, HP) vs NavigationRail (samping, tablet/desktop/web lebar), dan
/// di [MaxWidthBody] buat nge-cap lebar konten biar nggak mepet
/// edge-to-edge di layar lebar.
class AppBreakpoints {
  const AppBreakpoints._();

  /// >= ini dianggap "layar lebar" (tablet portrait ke atas, desktop, web
  /// window lebar) -> NavigationRail + konten di-cap lebar maksimalnya.
  static const tablet = 600.0;

  /// >= ini dianggap desktop/tablet landscape besar -> NavigationRail
  /// dikasih label penuh di samping ikon (bukan cuma ikon+label kecil).
  static const desktop = 1024.0;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= tablet;
}

/// Bungkus konten tiap tab (Beranda/Laporan/Statistik/Pengaturan) dengan
/// ini SEKALI di [MainShell] — otomatis berlaku buat semua tab tanpa perlu
/// ubah tiap screen satu-satu. Di HP (lebar < [AppBreakpoints.tablet]),
/// nggak ngefek apa-apa (tetap full-width, konten sudah didesain untuk
/// itu). Di layar lebar, konten di-cap ke [maxWidth] & di-tengahin, biar
/// nggak keliatan "meregang" jelek edge-to-edge kayak website yang belum
/// di-desain buat layar lebar.
///
/// [maxWidth] default 900 -- cukup luas buat dua kolom kartu di beberapa
/// screen (Laporan, Statistik) tapi tetap kebaca nyaman, nggak selebar
/// monitor desktop penuh.
class MaxWidthBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const MaxWidthBody({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) {
    if (!AppBreakpoints.isWide(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
