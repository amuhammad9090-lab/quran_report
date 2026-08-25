import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/week_utils.dart';
import '../../providers/records_provider.dart';
import 'status_badge.dart';

/// Kartu "1 santri = 1 card laporan utama" di tab Laporan. Nunjukin
/// identitas, progres pekan BULAN BERJALAN, progress bar, dan ringkasan
/// laporan terakhir (capaian + tanggal + keterangan).
///
/// Tap kolom pekan (_WeekChip) BUKA PANEL INFO pekan itu (di bawah baris
/// kolom pekan) dulu — bukan langsung buka form. Panel nunjukin status
/// pekan itu (kosong / ringkasan laporan yang sudah ada) plus SATU tombol
/// "Buat Laporan" / "Lihat & Ubah Laporan" yang baru manggil [onTapWeek].
/// Tap kolom pekan yang sama lagi -> panel nutup lagi.
///
/// Bagian kartu LAINNYA (header/identitas, progress, ringkasan) di-tap
/// buat buka sheet aksi "Pindahkan ke Folder" / "Hapus" (gaya kartu
/// laporan lama, [RecordCard] yang sekarang sudah dihapus) — "Ubah"
/// sengaja TIDAK ada di sini karena edit per-pekan sudah lewat panel info
/// pekan. Tahan-lama (hold) di luar mode pilih -> [onLongPressStartSelect]
/// (masuk mode pilih & langsung centang kartu ini), sama seperti pola
/// [RecordCard] lama. Kartu bisa digeser (drag) buat pindah folder cepat
/// selama [onPindahkanKeFolder] disediakan pemanggil — TERMASUK kartu yang
/// masih kosong (belum ada laporan sama sekali), lihat catatan di
/// [onPindahkanKeFolder]. Geser kartu ke kanan (swipe) = jalan pintas
/// "Hapus" tanpa buka sheet dulu, lihat [onHapus].
class SantriReportCard extends StatefulWidget {
  final SantriCardInfo info;

  /// Dipanggil dari tombol di panel info pekan (BUKAN langsung dari tap
  /// kolom pekan lagi) — [weekIndex] = nomor pekan DALAM BULAN (1-based)
  /// yang mau dibuka. Pemanggil (LaporanTab) yang memutuskan buka form
  /// baru atau form edit, tergantung pekan itu sudah ada laporannya atau
  /// belum.
  final void Function(int weekIndex) onTapWeek;

  /// Pindahkan SEMUA laporan santri ini ke folder (kalau [isInsideFolder]
  /// false) ATAU keluarkan dari folder yang lagi ditampilkan sekarang
  /// (kalau [isInsideFolder] true, mis. dipakai dari [FolderDetailScreen] —
  /// lihat dokumentasi [RecordsProvider.moveIdentityToFolder]). Boleh tetap
  /// disediakan walau kartu ini belum punya laporan sama sekali (kartu
  /// kosong) — pemanggil yang menentukan mau membolehkan drag kartu kosong
  /// atau tidak lewat null/non-null callback ini.
  final VoidCallback? onPindahkanKeFolder;

  /// True kalau kartu ini lagi ditampilkan DI DALAM sebuah folder (mis. di
  /// [FolderDetailScreen]) — mengubah label/ikon aksi [onPindahkanKeFolder]
  /// dari "Pindahkan ke Folder" jadi "Keluarkan dari Folder" di sheet aksi
  /// & drag feedback, karena di konteks ini aksinya memang mengeluarkan
  /// kartu dari folder yang sedang dibuka, bukan memindahkannya ke folder
  /// lain.
  final bool isInsideFolder;

  /// Hapus kartu ini (kartu kosong -> lepas identitas; kartu yang sudah
  /// ada laporannya -> semua laporannya ikut terhapus).
  final VoidCallback? onHapus;

  /// Mode pilih-banyak (dipicu dari tab Laporan lewat tombol "centang",
  /// atau tahan-lama kartu lewat [onLongPressStartSelect]) — pola persis
  /// sama seperti [RecordCard] lama.
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectToggle;

  /// Dipanggil kalau kartu ditahan-lama SAAT belum mode pilih — dipakai
  /// buat langsung masuk mode pilih & centang kartu ini. Kalau null,
  /// tahan-lama jatuh balik ke buka menu aksi (Pindahkan/Hapus).
  final VoidCallback? onLongPressStartSelect;

  /// Semua identityKey kartu yang lagi kecentang saat mode pilih aktif —
  /// dipakai biar drag salah satu kartu yang kecentang otomatis bawa
  /// semuanya sekaligus, bukan cuma kartu yang di-drag.
  final List<String>? selectedIds;

  const SantriReportCard({
    super.key,
    required this.info,
    required this.onTapWeek,
    this.onPindahkanKeFolder,
    this.isInsideFolder = false,
    this.onHapus,
    this.onLongPressStartSelect,
    this.selectedIds,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectToggle,
  });

  @override
  State<SantriReportCard> createState() => _SantriReportCardState();
}

class _SantriReportCardState extends State<SantriReportCard> {
  // Nomor pekan yang lagi buka panel info-nya di kartu INI, null = semua
  // tertutup (tampilan default kartu, ukuran sama seperti biasa).
  int? _expandedWeek;

  @override
  void didUpdateWidget(covariant SantriReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Masuk mode pilih -> tutup panel pekan yang lagi kebuka, biar kartu
    // dalam mode pilih selalu tampil ringkas & konsisten tingginya.
    if (widget.selectionMode && !oldWidget.selectionMode) {
      _expandedWeek = null;
    }
  }

  void _toggleWeek(int weekIndex) {
    setState(() {
      _expandedWeek = _expandedWeek == weekIndex ? null : weekIndex;
    });
  }

  void _showActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: Theme.of(ctx).bottomSheetTheme.backgroundColor,
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          widget.info.nama.isNotEmpty ? widget.info.nama[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.info.nama,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 18, indent: 18, endIndent: 18),
                if (widget.onPindahkanKeFolder != null)
                  ListTile(
                    leading: Icon(
                      widget.isInsideFolder ? Icons.folder_off_outlined : Icons.drive_file_move_outline,
                      color: widget.isInsideFolder ? cs.error : cs.secondary,
                    ),
                    title: Text(
                      widget.isInsideFolder ? 'Keluarkan dari Folder' : 'Pindahkan ke Folder',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onPindahkanKeFolder!();
                    },
                  ),
                if (widget.onHapus != null)
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                    title: Text('Hapus',
                        style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onHapus!();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekInfoPanel(BuildContext context, ColorScheme cs, DateTime thisMonth, int weekIndex) {
    // Ambil laporan pekan ini langsung dari provider (BUKAN dari
    // info.latestRecord, yang cuma laporan TERBARU keseluruhan, bisa beda
    // pekan) — biar panel selalu nunjukin isi pekan yang benar-benar
    // di-tap, bukan pekan lain.
    final record = context.watch<RecordsProvider>().recordForSantriInWeek(
          widget.info.nama,
          thisMonth,
          weekIndex,
        );
    final range = WeekUtils.monthWeekRange(thisMonth, weekIndex);
    final rangeStr = WeekUtils.rangeLabel(range);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Pekan $weekIndex • $rangeStr',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (record == null)
              Text(
                'Belum ada laporan pekan ini.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              )
            else ...[
              Row(
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.capaianText,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (record.totalBaris != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${record.totalBaris} baris',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => widget.onTapWeek(weekIndex),
                icon: Icon(record == null ? Icons.add_rounded : Icons.edit_outlined, size: 17),
                label: Text(record == null ? 'Buat Laporan' : 'Lihat / Ubah Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currentWeek = WeekUtils.weekOfMonth(now);
    // Bulan PEMILIK pekan hari ini (bisa beda dari now.month di 1-2 hari
    // ujung bulan) — lihat WeekUtils.ownerMonth.
    final thisMonth = WeekUtils.ownerMonth(now);
    final latest = widget.info.latestRecord;

    final canOpenActions = widget.onPindahkanKeFolder != null || widget.onHapus != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: widget.selected ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        onTap: widget.selectionMode
            ? widget.onSelectToggle
            : (canOpenActions ? () => _showActions(context) : null),
        onLongPress: widget.selectionMode
            ? null
            : (widget.onLongPressStartSelect ?? (canOpenActions ? () => _showActions(context) : null)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.selectionMode) ...[
                    Checkbox(
                      value: widget.selected,
                      onChanged: (_) => widget.onSelectToggle?.call(),
                    ),
                    const SizedBox(width: 2),
                  ],
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      widget.info.nama.isNotEmpty ? widget.info.nama[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.info.nama,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Kelas ${widget.info.kelas} • Halaqoh ${widget.info.halaqoh}',
                          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (latest != null)
                    StatusBadge(status: latest.status)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Baru',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(widget.info.totalWeeksThisMonth, (i) {
                  final weekIndex = i + 1;
                  final isLast = weekIndex == widget.info.totalWeeksThisMonth;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 6),
                      child: _WeekChip(
                        weekIndex: weekIndex,
                        filled: widget.info.weeksWithReportThisMonth.contains(weekIndex),
                        isCurrent: weekIndex == currentWeek,
                        isExpanded: _expandedWeek == weekIndex,
                        range: WeekUtils.monthWeekRange(thisMonth, weekIndex),
                        onTap: widget.selectionMode ? null : () => _toggleWeek(weekIndex),
                      ),
                    ),
                  );
                }),
              ),
              // Panel info pekan -- HANYA nongol kalau salah satu kolom
              // pekan lagi di-tap (_expandedWeek != null). Default-nya
              // tertutup, jadi tinggi kartu persis kayak sebelumnya.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _expandedWeek == null
                    ? const SizedBox(width: double.infinity)
                    : _buildWeekInfoPanel(context, cs, thisMonth, _expandedWeek!),
              ),
              if (latest != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_border_rounded, size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          latest.capaianText,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (latest.totalBaris != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${latest.totalBaris} baris',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      DateFormat('d MMM yyyy', 'id_ID').format(latest.tanggal),
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                    const Spacer(),
                    KeteranganChip(keterangan: latest.keterangan, compact: true),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget card = _buildCard(context);

    // Drag-to-folder (tahan-geser): aktif di luar mode pilih (drag kartu
    // ini sendirian), ATAU saat mode pilih aktif dan kartu ini termasuk
    // yang dicentang — sama seperti [RecordCard] lama. Sengaja TIDAK
    // digantung ke [SantriCardInfo.hasAnyReport] di sini -- kartu yang
    // masih kosong TETAP bisa didrag selama pemanggil menyediakan
    // [onPindahkanKeFolder] (lihat dokumentasi field itu).
    final canDrag = widget.onPindahkanKeFolder != null && (!widget.selectionMode || widget.selected);

    if (canDrag) {
      final dragIds = (widget.selectionMode && widget.selected && (widget.selectedIds?.isNotEmpty ?? false))
          ? widget.selectedIds!
          : [widget.info.identityKey];

      card = LongPressDraggable<List<String>>(
        data: dragIds,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 260,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(opacity: 0.9, child: _buildCard(context)),
                if (dragIds.length > 1)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${dragIds.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      );
    }

    return Slidable(
      key: ValueKey(widget.info.identityKey),
      // Geser ke KANAN (drag dari kiri) -> buka pane di sisi awal (start),
      // sesuai request: hapus laporan tinggal geser card ke kanan.
      startActionPane: (widget.onHapus == null || widget.selectionMode)
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.24,
              children: [
                SlidableAction(
                  onPressed: (_) => widget.onHapus!(),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  borderRadius: BorderRadius.circular(20),
                ),
              ],
            ),
      child: card,
    );
  }
}

/// Satu kolom "PEKAN N" — 3 kemungkinan tampilan: sudah ada laporan
/// (centang hijau), pekan berjalan tapi belum diisi (outline "+", diajak
/// isi), atau pekan lain yang belum diisi (netral, angka pekan biasa).
/// Tap = toggle panel info pekan itu (lihat [SantriReportCard]), BUKAN
/// langsung buka form lagi -- makanya outline ganti warna kalau
/// [isExpanded] true, biar user tau panel yang lagi kebuka pekan mana.
class _WeekChip extends StatelessWidget {
  final int weekIndex;
  final bool filled;
  final bool isCurrent;
  final bool isExpanded;
  final MonthWeekRange range;
  final VoidCallback? onTap;

  const _WeekChip({
    required this.weekIndex,
    required this.filled,
    required this.isCurrent,
    required this.isExpanded,
    required this.range,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = (filled || isCurrent || isExpanded) ? cs.primary : cs.onSurfaceVariant;
    final bg = filled
        ? cs.primary.withValues(alpha: 0.12)
        : (isCurrent ? cs.primary.withValues(alpha: 0.06) : cs.surfaceContainerHighest.withValues(alpha: 0.35));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: (isExpanded || (isCurrent && !filled)) ? Border.all(color: cs.primary, width: 1.3) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filled ? Icons.check_circle_rounded : (isCurrent ? Icons.add_circle_outline_rounded : Icons.circle_outlined),
                size: 15,
                color: accent,
              ),
              const SizedBox(height: 3),
              Text(
                'P$weekIndex',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent),
              ),
              Text(
                '${range.start.day}-${range.end.day}',
                style: TextStyle(fontSize: 8.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
