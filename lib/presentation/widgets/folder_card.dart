import 'package:flutter/material.dart';

import '../../data/models/folder.dart';

/// Kartu folder di section "Folder" pada tab Laporan.
/// - Tap → buka halaman isi folder.
/// - Tekan lama (hold) → menu Ubah Nama / Hapus.
/// - Jadi [DragTarget] — kalau ada RecordCard yang di-drag (id laporan)
///   dilepas di atas kartu ini, laporan itu dipindah ke folder ini.
class FolderCard extends StatelessWidget {
  final ReportFolder folder;
  final int recordCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(List<String> recordIds)? onDropRecord;

  const FolderCard({
    super.key,
    required this.folder,
    required this.recordCount,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.onDropRecord,
  });

  void _showActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(ctx).bottomSheetTheme.backgroundColor,
            borderRadius: BorderRadius.circular(22),
          ),
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
                    Icon(Icons.folder_rounded, color: cs.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        folder.nama,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18, indent: 18, endIndent: 18),
              ListTile(
                leading: Icon(Icons.drive_file_rename_outline_rounded, color: cs.primary),
                title: const Text('Ubah Nama', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRename();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text('Hapus Folder',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) => onDropRecord != null,
      onAcceptWithDetails: (details) => onDropRecord?.call(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedScale(
          scale: hovering ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Card(
            color: hovering ? cs.secondaryContainer.withValues(alpha: 0.6) : null,
            child: InkWell(
              onTap: onTap,
              onLongPress: () => _showActions(context),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.folder_rounded, color: cs.secondary, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      folder.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$recordCount laporan',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
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
