import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/folders_provider.dart';
import '../../widgets/misc_widgets.dart';
import 'folder_form_sheet.dart';

/// Bottom sheet pilih folder tujuan — dipakai buat "Pindahkan ke Folder"
/// (satu laporan) maupun mode centang (banyak laporan sekaligus).
/// Mengembalikan folderId yang dipilih user, atau null kalau dibatalkan.
Future<String?> showFolderPickerSheet(
  BuildContext context, {
  String? currentFolderId,
  int itemCount = 1,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FolderPickerSheet(currentFolderId: currentFolderId, itemCount: itemCount),
  );
}

class _FolderPickerSheet extends StatelessWidget {
  final String? currentFolderId;
  final int itemCount;
  const _FolderPickerSheet({required this.currentFolderId, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final folders = context.watch<FoldersProvider>().all;

    return SafeArea(
      child: Container(
        // Container ini SEKARANG cuma buat `constraints` — background +
        // rounded corner dipindah ke Material di dalamnya, biar ListTile
        // di list folder & aksi (di bawah) punya Material terdekat yang
        // benar, nggak ketutup DecoratedBox lagi (lihat assertion "ListTile
        // background color or ink splashes may be invisible").
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Material(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  'Pindahkan ${itemCount > 1 ? '$itemCount Laporan' : 'Laporan'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Pilih folder tujuan', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 14),
                Flexible(
                  child: folders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'Belum ada folder. Buat folder dulu di bawah.',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: folders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, i) {
                            final f = folders[i];
                            final isCurrent = f.id == currentFolderId;
                            return ListTile(
                              leading: SoftIconBox(icon: Icons.folder_rounded, color: cs.secondary),
                              title: Text(f.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: isCurrent ? Icon(Icons.check_rounded, color: cs.primary) : null,
                              onTap: isCurrent ? null : () => Navigator.pop(context, f.id),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                if (currentFolderId != null)
                  ListTile(
                    leading: SoftIconBox(icon: Icons.folder_off_outlined, color: cs.error),
                    title: const Text('Keluarkan dari Folder', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(context, ''),
                  ),
                const Divider(height: 20),
                ListTile(
                  leading: SoftIconBox(icon: Icons.create_new_folder_rounded, color: cs.primary),
                  title: const Text('Buat Folder Baru', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(context);
                    await showFolderFormSheet(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
