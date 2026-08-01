/// Network switch (mainnet/testnet) and destructive wallet wipe, with an
/// explicit confirmation dialog before anything irreversible happens.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/network_config.dart';
import '../services/wallet_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmWipe(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wipe wallet?'),
        content: const Text(
          'This deletes your recovery phrase from this device. If you have '
          'not backed it up elsewhere, any funds will be permanently '
          'unrecoverable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Wipe', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<WalletService>().wipeWallet();
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Network', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<CacNetwork>(
            title: const Text('Mainnet'),
            value: CacNetwork.mainnet,
            groupValue: wallet.network.network,
            onChanged: (v) => wallet.switchNetwork(v!),
          ),
          RadioListTile<CacNetwork>(
            title: const Text('Testnet'),
            value: CacNetwork.testnet,
            groupValue: wallet.network.network,
            onChanged: (v) => wallet.switchNetwork(v!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Wipe wallet', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmWipe(context),
          ),
        ],
      ),
    );
  }
}
