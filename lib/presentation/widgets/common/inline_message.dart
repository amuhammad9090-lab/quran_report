import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Pesan singkat inline (pengganti SnackBar) sebagai bagian Column bottom sheet
/// tanpa Scaffold sendiri (SnackBar biasa tergambar di balik sheet). Pakai
/// `with InlineMessageMixin<T>`, panggil [showInlineMessage], render [InlineMessageBanner].
mixin InlineMessageMixin<T extends StatefulWidget> on State<T> {
  String? inlineMessage;
  Timer? _inlineMessageTimer;

  void showInlineMessage(String message) {
    _inlineMessageTimer?.cancel();
    setState(() => inlineMessage = message);
    _inlineMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => inlineMessage = null);
    });
  }

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    super.dispose();
  }
}

/// Banner pesan singkat inline — lihat [InlineMessageMixin].
class InlineMessageBanner extends StatelessWidget {
  final String message;
  const InlineMessageBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.info, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
