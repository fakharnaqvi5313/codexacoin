/// Send flow: scan or paste a destination address, enter an amount, fetch
/// this wallet's UTXOs (across every address it's generated -- see
/// WalletService.gatherAllUtxos) from the gateway, sign locally, and
/// broadcast. Signing happens entirely on-device (crypto/transaction.dart);
/// the gateway only ever sees the final signed raw transaction hex.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../crypto/transaction.dart' as tx;
import '../services/bip21.dart';
import '../services/price_service.dart';
import '../services/wallet_service.dart';
import 'qr_scan_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _txid;

  // Fetched once per screen visit, then just multiplied locally against
  // whatever's typed -- no point re-hitting the price API per keystroke.
  CacPrice? _price;

  @override
  void initState() {
    super.initState();
    fetchCacUsdPrice().then((p) {
      if (mounted) setState(() => _price = p);
    });
    // Rebuilds on every keystroke so the fiat estimate below the amount
    // field stays current -- setState with no controller-derived state
    // change is fine here since build() reads straight from the
    // controller's current text.
    _amountController.addListener(() => setState(() {}));
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Scan address')),
    );
    if (result != null) {
      final parsed = parseBip21(result);
      setState(() {
        _addressController.text = parsed.address;
        if (parsed.amount != null) _amountController.text = parsed.amount.toString();
      });
    }
  }

  void _onAddressChanged(String value) {
    final parsed = parseBip21(value);
    if (parsed.address != value) {
      _addressController.text = parsed.address;
      if (parsed.amount != null) _amountController.text = parsed.amount.toString();
    }
  }

  Future<void> _openAddressBook() async {
    final wallet = context.read<WalletService>();
    final entries = await wallet.loadAddressBook();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddressBookSheet(
        entries: entries,
        onSave: (updated) => wallet.saveAddressBook(updated),
      ),
    );
    if (picked != null) {
      setState(() => _addressController.text = picked);
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
      _txid = null;
    });
    try {
      final wallet = context.read<WalletService>();
      final amountCac = double.tryParse(_amountController.text.trim());
      if (amountCac == null || amountCac <= 0) {
        throw ArgumentError('Enter a valid amount');
      }
      final amountSatoshis = (amountCac * 100000000).round();

      final allUtxos = await wallet.gatherAllUtxos();
      if (allUtxos.isEmpty) {
        throw StateError('No spendable funds found');
      }

      final feeJson = await wallet.gateway.feeEstimate();
      final feeRate = int.tryParse(feeJson['fee_rate_sat_per_vbyte']?.toString() ?? '') ?? 1;

      var totalIn = 0;
      final chosen = <tx.Utxo>[];
      for (final u in allUtxos) {
        chosen.add(u);
        totalIn += u.valueSatoshis;
        // Scaled by input count, not a fixed guess -- once a send can span
        // more than one address's UTXOs a single-input estimate stops
        // being reasonable. Still a rough estimate, not real dynamic fee
        // estimation (this gateway has none -- see mobile-api.md section 4).
        final estimatedVsize = 10 + chosen.length * 148 + 2 * 34;
        final feeSatoshis = (feeRate * estimatedVsize) ~/ 1000;
        if (totalIn >= amountSatoshis + feeSatoshis) break;
      }
      final finalVsize = 10 + chosen.length * 148 + 2 * 34;
      final feeSatoshis = (feeRate * finalVsize) ~/ 1000;
      if (totalIn < amountSatoshis + feeSatoshis) {
        throw StateError('Insufficient funds: have $totalIn, need ${amountSatoshis + feeSatoshis}');
      }

      final txid = await wallet.sendTransaction(
        utxos: chosen,
        toAddress: _addressController.text.trim(),
        amountSatoshis: amountSatoshis,
        feeSatoshis: feeSatoshis,
      );
      setState(() => _txid = txid);
      _addressController.clear();
      _amountController.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _addressController,
              onChanged: _onAddressChanged,
              decoration: InputDecoration(
                labelText: 'Destination address',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.contacts_outlined),
                      tooltip: 'Address book',
                      onPressed: _openAddressBook,
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan QR',
                      onPressed: _scanQr,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (CAC)',
                border: OutlineInputBorder(),
              ),
            ),
            Builder(builder: (context) {
              final amount = double.tryParse(_amountController.text.trim());
              if (_price == null || amount == null || amount <= 0) {
                return const SizedBox.shrink();
              }
              final usdValue = amount * _price!.usdPerCac;
              final sourceLabel =
                  _price!.source == CacPriceSource.bnb ? 'PancakeSwap (BNB Chain)' : 'Stellar DEX';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '~\$${usdValue.toStringAsFixed(2)} (estimated -- thin $sourceLabel liquidity, not a reliable market price)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              );
            }),
            const SizedBox(height: 24),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            if (_txid != null) Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('Broadcast: $_txid',
                  style: const TextStyle(color: Colors.green)),
            ),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _sending
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressBookSheet extends StatefulWidget {
  final List<Map<String, String>> entries;
  final Future<void> Function(List<Map<String, String>>) onSave;
  const _AddressBookSheet({required this.entries, required this.onSave});

  @override
  State<_AddressBookSheet> createState() => _AddressBookSheetState();
}

class _AddressBookSheetState extends State<_AddressBookSheet> {
  late List<Map<String, String>> _entries;
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
  }

  Future<void> _add() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    if (label.isEmpty || address.isEmpty) return;
    setState(() => _entries = [..._entries, {'label': label, 'address': address}]);
    await widget.onSave(_entries);
    _labelController.clear();
    _addressController.clear();
  }

  Future<void> _remove(int index) async {
    setState(() => _entries = [..._entries]..removeAt(index));
    await widget.onSave(_entries);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Address book', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No saved addresses yet.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e['label'] ?? ''),
                      subtitle: Text(e['address'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      onTap: () => Navigator.of(context).pop(e['address']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(i),
                      ),
                    );
                  },
                ),
              ),
            const Divider(),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _add, child: const Text('Save address')),
          ],
        ),
      ),
    );
  }
}
