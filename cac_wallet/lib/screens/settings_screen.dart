/// Network switch (mainnet/testnet) and destructive wallet wipe, with an
/// explicit confirmation dialog before anything irreversible happens.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/network_config.dart';
import '../crypto/message.dart' as msg;
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<String>(
            title: const Text('System'),
            value: 'system',
            groupValue: wallet.themeMode,
            onChanged: (v) => wallet.setThemeMode(v!),
          ),
          RadioListTile<String>(
            title: const Text('Dark'),
            value: 'dark',
            groupValue: wallet.themeMode,
            onChanged: (v) => wallet.setThemeMode(v!),
          ),
          RadioListTile<String>(
            title: const Text('Light'),
            value: 'light',
            groupValue: wallet.themeMode,
            onChanged: (v) => wallet.setThemeMode(v!),
          ),
          const Divider(),
          const _MessageToolCard(),
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

/// Sign a message with one of this wallet's addresses, or verify a
/// signature against any address -- proves control of an address
/// without spending anything. See lib/crypto/message.dart.
class _MessageToolCard extends StatefulWidget {
  const _MessageToolCard();

  @override
  State<_MessageToolCard> createState() => _MessageToolCardState();
}

class _MessageToolCardState extends State<_MessageToolCard> {
  int? _signIndex;
  final _signMessageController = TextEditingController();
  String? _signOutput;
  String? _signError;

  final _verifyAddressController = TextEditingController();
  final _verifyMessageController = TextEditingController();
  final _verifySignatureController = TextEditingController();
  String? _verifyError;
  String? _verifySuccess;

  @override
  void dispose() {
    _signMessageController.dispose();
    _verifyAddressController.dispose();
    _verifyMessageController.dispose();
    _verifySignatureController.dispose();
    super.dispose();
  }

  Future<void> _sign(WalletService wallet) async {
    setState(() {
      _signError = null;
      _signOutput = null;
    });
    final index = _signIndex ?? wallet.activeIndex;
    if (_signMessageController.text.isEmpty) {
      setState(() => _signError = 'Enter a message to sign.');
      return;
    }
    try {
      final key = await wallet.ensureKey(index);
      final signature = msg.signMessage(key.privateKey, key.publicKey, _signMessageController.text);
      setState(() => _signOutput = signature);
    } catch (e) {
      setState(() => _signError = 'Could not sign message: $e');
    }
  }

  void _verify(WalletService wallet) {
    setState(() {
      _verifyError = null;
      _verifySuccess = null;
    });
    final address = _verifyAddressController.text.trim();
    final signature = _verifySignatureController.text.trim();
    if (address.isEmpty || signature.isEmpty) {
      setState(() => _verifyError = 'Enter an address and a signature to verify.');
      return;
    }
    try {
      final valid = msg.verifyMessage(address, signature, _verifyMessageController.text, wallet.network);
      setState(() {
        if (valid) {
          _verifySuccess = 'Valid signature -- this address signed this exact message.';
        } else {
          _verifyError = 'Invalid signature -- does not match this address/message.';
        }
      });
    } catch (e) {
      setState(() => _verifyError = 'Could not verify signature: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    final signIndex = _signIndex ?? wallet.activeIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sign a message', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Proves control of one of your addresses, without spending '
            'anything -- e.g. to verify your identity to someone else '
            'off-chain.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: signIndex,
            decoration: const InputDecoration(labelText: 'Sign as', border: OutlineInputBorder()),
            items: [
              for (final idx in wallet.addressIndices)
                DropdownMenuItem(value: idx, child: Text(wallet.addressAt(idx), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _signIndex = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _signMessageController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _sign(wallet), child: const Text('Sign')),
          if (_signOutput != null) ...[
            const SizedBox(height: 8),
            SelectableText(_signOutput!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
          if (_signError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_signError!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          const Text('Verify a message', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _verifyAddressController,
            decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _verifyMessageController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _verifySignatureController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Signature', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _verify(wallet), child: const Text('Verify')),
          if (_verifySuccess != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_verifySuccess!, style: const TextStyle(color: Colors.green)),
            ),
          if (_verifyError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_verifyError!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
