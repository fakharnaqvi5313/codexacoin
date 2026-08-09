/// Main wallet screen: balance + navigation to send/receive/history/
/// staking/settings. Balance is fetched once on open and via pull-to-refresh
/// -- no polling timers (see docs/store-compliance.md, "no background work").
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import '../widgets/fiat_placeholder.dart';
import 'history_screen.dart';
import 'multisig_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'settings_screen.dart';
import 'staking_screen.dart';
import 'watch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Balance? _balance;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = context.read<WalletService>();
      final json = await wallet.fetchBalance();
      setState(() => _balance = Balance.fromJson(json));
    } catch (e) {
      setState(() => _error = 'Could not reach the network: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CodexaCoin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              wallet.network.name,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      children: [
                        Text(
                          '${formatCac(_balance?.total ?? BigInt.zero)} CAC',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        FiatPlaceholder(cacAmount: (_balance?.total ?? BigInt.zero).toDouble() / 1e8),
                      ],
                    ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_upward,
                    label: 'Send',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SendScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_downward,
                    label: 'Receive',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.history,
                    label: 'History',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.savings_outlined,
                    label: 'Staking',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StakingScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.groups_outlined,
                    label: 'Multisig',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MultisigScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.visibility_outlined,
                    label: 'Watch',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WatchScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
