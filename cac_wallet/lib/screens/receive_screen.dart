/// Displays the wallet's active receive address as text + QR code, plus
/// every other address this wallet has generated on this device (see
/// WalletService.generateNewAddress for what "generated" means here --
/// not full BIP44 gap-limit discovery).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/wallet_service.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _generating = false;

  Future<void> _newAddress() async {
    setState(() => _generating = true);
    try {
      await context.read<WalletService>().generateNewAddress();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    final address = wallet.activeAddress();
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: address,
              version: QrVersions.auto,
              size: 240,
            ),
          ),
          const SizedBox(height: 24),
          SelectableText(
            address,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy address'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied')),
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Previously used addresses', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'This wallet derives a new address each time you tap "New address" '
            'below rather than automatically rotating one for you -- balance '
            'and history are combined across every address you\'ve generated. '
            'It does not scan for addresses used elsewhere (e.g. by another '
            'copy of this wallet restored from the same phrase) beyond what\'s '
            'listed here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final idx in wallet.addressIndices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                wallet.addressAt(idx),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: idx == wallet.activeIndex ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              trailing: idx == wallet.activeIndex
                  ? const Text('Current')
                  : TextButton(
                      onPressed: () => wallet.setActiveIndex(idx),
                      child: const Text('Use'),
                    ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _generating ? null : _newAddress,
            child: _generating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('New address'),
          ),
        ],
      ),
    );
  }
}
