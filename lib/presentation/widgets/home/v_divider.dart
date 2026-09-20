import 'package:flutter/material.dart';

/// Garis vertikal tipis pemisah antar [StatItem].
class VDivider extends StatelessWidget {
  const VDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: Theme.of(context).dividerTheme.color,
    );
  }
}
