/// Send flow: scan or paste a destination address, enter an amount, fetch
/// this wallet's UTXOs from the gateway, sign locally, and broadcast.
/// Signing happens entirely on-device (crypto/transaction.dart); the
/// gateway only ever sees the final signed raw transaction hex.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../crypto/transaction.dart' as tx;
import '../services/wallet_service.dart';

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

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (result != null) {
      setState(() => _addressController.text = result);
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
      final address = wallet.activeAddress();
      final amountCac = double.tryParse(_amountController.text.trim());
      if (amountCac == null || amountCac <= 0) {
        throw ArgumentError('Enter a valid amount');
      }
      final amountSatoshis = (amountCac * 100000000).round();

      final utxoJson = await wallet.gateway.utxos(address);
      final utxoList = utxoJson['utxos'] as List<dynamic>? ?? const [];
      if (utxoList.isEmpty) {
        throw StateError('No spendable funds found for this address');
      }
      final utxos = utxoList.map((u) {
        final m = u as Map<String, dynamic>;
        return tx.Utxo(
          txid: _hexToBytes(m['txid'] as String),
          vout: m['vout'] as int,
          valueSatoshis: int.parse(m['value'].toString()),
          pubkeyHash: _hexToBytes(m['pubkey_hash'] as String),
        );
      }).toList();

      final feeJson = await wallet.gateway.feeEstimate();
      final feeSatoshis = int.tryParse(feeJson['fee_satoshis']?.toString() ?? '') ?? 1000;

      final txid = await wallet.sendTransaction(
        utxos: utxos,
        toAddress: _addressController.text.trim(),
        amountSatoshis: amountSatoshis,
        feeSatoshis: feeSatoshis,
      );
      setState(() => _txid = txid);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Uint8List _hexToBytes(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
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
              decoration: InputDecoration(
                labelText: 'Destination address',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanQr,
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

class _QrScanScreen extends StatelessWidget {
  const _QrScanScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan address')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            Navigator.of(context).pop(barcodes.first.rawValue);
          }
        },
      ),
    );
  }
}
