/// Staking status display. Read-only + remote-calls-only by design -- this
/// screen never computes a reward, mints a coinstake, or runs anything on
/// a timer. All figures come from the gateway's /staking/status endpoint,
/// which does not have a real backend yet (Phase 6); see
/// docs/store-compliance.md for why this separation matters for App
/// Store / Play Store review.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

class StakingScreen extends StatefulWidget {
  const StakingScreen({super.key});

  @override
  State<StakingScreen> createState() => _StakingScreenState();
}

class _StakingScreenState extends State<StakingScreen> {
  StakingStatus? _status;
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
      final json = await wallet.gateway.stakingStatus('');
      setState(() => _status = StakingStatus.fromJson(json));
    } catch (e) {
      // No staking backend exists yet (Phase 6) -- fall back to the
      // "not opted in" placeholder rather than showing a scary error for
      // a feature that legitimately isn't live yet.
      setState(() => _status = StakingStatus.notOptedIn);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Staking')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status!.mode == 'none' ? 'Not staking' : 'Mode: ${status.mode}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _row('Delegated', '${formatCac(status.delegatedAmount)} CAC'),
                          _row('Accrued rewards', '${formatCac(status.accruedRewards)} CAC'),
                          _row('Rate', '${status.effectiveMonthlyRateBp / 100}% / month'),
                          _row('Pool fee', '${status.poolFeeBp / 100}%'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rewards accrue automatically on the network -- no need to keep '
                    'this app open or online. This screen only displays status '
                    'reported by the CodexaCoin network; staking itself never runs '
                    'on this device.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: status.mode == 'none' ? _notYetAvailable : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Start staking'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: status.canWithdraw ? _notYetAvailable : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Withdraw'),
                    ),
                  ),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
      ),
    );
  }

  void _notYetAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Staking service is not live yet (coming in a later phase)')),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}
