/// Best-effort estimated fiat value. Was a hardcoded "unavailable"
/// placeholder for most of this project's life because no price for CAC
/// existed anywhere -- see docs/store-compliance.md's note on not
/// misleading users about values the app doesn't actually have. That's
/// no longer true now that CAC trades (thinly) on Stellar's DEX, so this
/// fetches a real, sourced number -- but stays honest about how thin
/// that source is rather than presenting it as a confident market price.
library;

import 'package:flutter/material.dart';

import '../services/price_service.dart';

class FiatPlaceholder extends StatefulWidget {
  final double cacAmount;
  const FiatPlaceholder({super.key, required this.cacAmount});

  @override
  State<FiatPlaceholder> createState() => _FiatPlaceholderState();
}

class _FiatPlaceholderState extends State<FiatPlaceholder> {
  CacPrice? _price;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    fetchCacUsdPrice().then((p) {
      if (mounted) setState(() { _price = p; _loaded = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    if (!_loaded) return Text('Fetching estimated value...', style: style);
    if (_price == null) return Text('Fiat value unavailable', style: style);
    final usdValue = widget.cacAmount * _price!.usdPerCac;
    return Text(
      '~\$${usdValue.toStringAsFixed(2)} (estimated -- thin Stellar DEX liquidity, not a reliable market price)',
      style: style,
      textAlign: TextAlign.center,
    );
  }
}
