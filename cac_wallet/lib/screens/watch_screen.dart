/// Monitor an arbitrary address's balance without holding its keys --
/// pure read-only utility, no send capability, separate from this
/// wallet's own derived addresses and from the address book (which is
/// for send-flow reuse, not monitoring).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  List<Map<String, String>> _entries = [];
  final Map<int, String> _balances = {};
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wallet = context.read<WalletService>();
    final entries = await wallet.loadWatchList();
    if (!mounted) return;
    setState(() => _entries = entries);
    for (var i = 0; i < entries.length; i++) {
      _fetchBalance(i, entries[i]['address']!);
    }
  }

  Future<void> _fetchBalance(int index, String address) async {
    try {
      final wallet = context.read<WalletService>();
      final json = await wallet.gateway.balance(address);
      final balance = Balance.fromJson(json);
      if (mounted) setState(() => _balances[index] = '${formatCac(balance.total)} CAC');
    } catch (e) {
      if (mounted) setState(() => _balances[index] = 'Could not fetch balance');
    }
  }

  Future<void> _add() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    if (label.isEmpty || address.isEmpty) return;
    final wallet = context.read<WalletService>();
    final entries = [..._entries, {'label': label, 'address': address}];
    await wallet.saveWatchList(entries);
    _labelController.clear();
    _addressController.clear();
    await _load();
  }

  Future<void> _remove(int index) async {
    final wallet = context.read<WalletService>();
    final entries = [..._entries]..removeAt(index);
    await wallet.saveWatchList(entries);
    await _load();
  }

  Future<void> _viewOnExplorer(String address) async {
    final uri = Uri.parse('https://codexacoin.com/blockexplorer/#/address/$address');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watch')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "Add any CodexaCoin address to monitor its balance -- no keys "
            "involved, this can't spend anything. Useful for keeping an eye "
            "on an address that isn't part of this wallet.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(controller: _labelController, decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _add, child: const Text('Add address')),
          const SizedBox(height: 24),
          if (_entries.isEmpty) const Text('No watched addresses yet.', style: TextStyle(color: Colors.grey)),
          for (var i = 0; i < _entries.length; i++)
            Card(
              child: ListTile(
                title: Text(_entries[i]['label'] ?? ''),
                subtitle: Text(
                  '${_entries[i]['address']}\n${_balances[i] ?? 'Loading balance...'}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Explorer',
                      onPressed: () => _viewOnExplorer(_entries[i]['address']!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove',
                      onPressed: () => _remove(i),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
