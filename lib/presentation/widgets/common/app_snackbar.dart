import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Snackbar seragam (ikon + pesan, rounded) pengganti [SnackBar] polos; nempel 16px
/// di atas apa pun di bawahnya. Kalau layar punya FAB, sembunyikan FAB lewat
/// [onFabVisibilityChanged] selama snackbar tampil, bukan menambah jarak ekstra.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackbar(
    BuildContext context,
    String message, {
      IconData icon = LucideIcons.circleCheck,
      ValueChanged<bool>? onFabVisibilityChanged,
    }) {
  final cs = Theme.of(context).colorScheme;
  onFabVisibilityChanged?.call(false);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(child: Text(message)),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ),
  );
  controller.closed.then((_) => onFabVisibilityChanged?.call(true));
  return controller;
}
