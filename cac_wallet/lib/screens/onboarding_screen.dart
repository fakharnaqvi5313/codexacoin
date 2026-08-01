/// First-run flow: create a new wallet (show mnemonic once) or restore
/// from an existing recovery phrase. No network calls happen here.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/wallet_service.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 72),
              const SizedBox(height: 16),
              const Text(
                'CodexaCoin Wallet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _CreateWalletFlow()),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Create a new wallet'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _RestoreWalletFlow()),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Restore from recovery phrase'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateWalletFlow extends StatefulWidget {
  const _CreateWalletFlow();

  @override
  State<_CreateWalletFlow> createState() => _CreateWalletFlowState();
}

class _CreateWalletFlowState extends State<_CreateWalletFlow> {
  String? _mnemonic;
  bool _confirmed = false;

  Future<void> _generate() async {
    final wallet = context.read<WalletService>();
    // Generate and hold in memory for display only; wallet_service already
    // persisted it to secure storage as part of createNewWallet().
    final mnemonic = await wallet.createNewWallet();
    setState(() => _mnemonic = mnemonic);
  }

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your recovery phrase')),
      body: _mnemonic == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Write down these 12 words in order and store them somewhere '
                    'safe. Anyone with this phrase can spend your funds. '
                    'CodexaCoin cannot recover it for you.',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _mnemonic!,
                      style: const TextStyle(fontSize: 18, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('I have written down my recovery phrase'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _confirmed
                        ? () => Navigator.of(context).popUntil((r) => r.isFirst)
                        : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RestoreWalletFlow extends StatefulWidget {
  const _RestoreWalletFlow();

  @override
  State<_RestoreWalletFlow> createState() => _RestoreWalletFlowState();
}

class _RestoreWalletFlowState extends State<_RestoreWalletFlow> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<WalletService>().restoreWallet(_controller.text.trim());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore wallet')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your 12-word recovery phrase, separated by spaces.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'word1 word2 word3 ...',
              ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _restore,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Restore'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
