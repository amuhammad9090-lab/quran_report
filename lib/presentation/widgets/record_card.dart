import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../data/models/santri_record.dart';
import 'status_badge.dart';

class RecordCard extends StatelessWidget {
  final SantriRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPindahkanKeFolder;
  final String pindahkanLabel;
  final IconData pindahkanIcon;

  /// Mode pilih-banyak (dipicu dari tab Laporan lewat tombol "centang",
  /// atau tahan-lama kartu lewat [onLongPressStartSelect]).
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectToggle;

  /// Dipanggil kalau kartu ditahan-lama SAAT belum mode pilih — dipakai
  /// buat langsung masuk mode pilih & centang kartu ini. Kalau null,
  /// tahan-lama jatuh balik ke buka menu aksi (Ubah/Pindahkan/Hapus) —
  /// dipakai layar yang belum wire up mode pilih (mis. rekap statistik).
  final VoidCallback? onLongPressStartSelect;

  /// Semua id laporan yang lagi kecentang saat mode pilih aktif — dipakai
  /// biar drag salah satu kartu yang kecentang otomatis bawa semuanya
  /// sekaligus, bukan cuma kartu yang di-drag.
  final List<String>? selectedIds;

  const RecordCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    this.onPindahkanKeFolder,
    this.pindahkanLabel = 'Pindahkan ke Folder',
    this.pindahkanIcon = Icons.drive_file_move_outline,
    this.onLongPressStartSelect,
    this.selectedIds,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectToggle,
  });

  void _showActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          // Container ini SEKARANG cuma buat `margin` (nggak ada decoration
          // lagi di sini) — background+rounded corner dipindah ke Material
          // di dalamnya, biar ListTile "Ubah"/"Pindahkan"/"Hapus" di bawah
          // punya Material terdekat yang benar, nggak ketutup DecoratedBox
          // (lihat assertion "ListTile background color or ink splashes
          // may be invisible"). Margin tetap di sini (di LUAR area
          // berwarna) supaya tampilan inset-nya persis sama seperti
          // sebelumnya.
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
                        record.namaAnak.isNotEmpty
                            ? record.namaAnak[0].toUpperCase()
                            : '?',
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
                        record.namaAnak,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18, indent: 18, endIndent: 18),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: cs.primary),
                title: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
              ),
              if (onPindahkanKeFolder != null)
                ListTile(
                  leading: Icon(pindahkanIcon, color: cs.secondary),
                  title: Text(pindahkanLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPindahkanKeFolder!();
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text('Hapus',
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
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

  Widget _buildCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM yyyy', 'id_ID').format(record.tanggal);
    final timeStr = DateFormat('HH:mm').format(record.createdAt ?? record.tanggal);

    return Card(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        onTap: selectionMode ? onSelectToggle : () => _showActions(context),
        onLongPress: selectionMode
            ? null
            : (onLongPressStartSelect ?? () => _showActions(context)),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectionMode) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onSelectToggle?.call(),
                    ),
                    const SizedBox(width: 2),
                  ],
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      record.namaAnak.isNotEmpty ? record.namaAnak[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.namaAnak,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kelas ${record.kelas} • Halaqoh ${record.halaqoh}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: record.status),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.capaianText,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (record.totalBaris != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${record.totalBaris} baris',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.access_time_rounded, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  KeteranganChip(keterangan: record.keterangan, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget card = _buildCard(context);

    // Drag-to-folder (tahan-geser): aktif di luar mode pilih (drag kartu ini
    // sendirian), ATAU saat mode pilih aktif dan kartu ini termasuk yang
    // dicentang — dalam kasus itu, drag bawa SEMUA kartu yang kecentang
    // sekaligus (bukan cuma kartu yang lagi disentuh).
    final canDrag = onPindahkanKeFolder != null && (!selectionMode || selected);

    if (canDrag) {
      final dragIds = (selectionMode && selected && (selectedIds?.isNotEmpty ?? false))
          ? selectedIds!
          : [record.id];

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
      key: ValueKey(record.id),
      endActionPane: selectionMode
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.24,
              children: [
                SlidableAction(
                  onPressed: (_) => onDelete(),
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
