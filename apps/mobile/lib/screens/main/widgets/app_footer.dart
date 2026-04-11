import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text("HOTDROP KINETIC\nPROTOCOL V4.2.0", style: style)),
        Expanded(child: Text("ENCRYPTED", style: style)),
        Expanded(child: Text("P2P\nMESH\nACTIVE", style: style)),
      ],
    );
  }
}