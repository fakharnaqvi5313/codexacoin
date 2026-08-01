/// Explicit fiat-value placeholder. No live price feed exists yet -- this
/// deliberately does not show a fabricated number (see
/// docs/store-compliance.md's note on not misleading users about values
/// the app doesn't actually have).
library;

import 'package:flutter/material.dart';

class FiatPlaceholder extends StatelessWidget {
  const FiatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Fiat value unavailable',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
    );
  }
}
