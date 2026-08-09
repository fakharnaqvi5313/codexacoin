/// Transaction history list for the active address. One fetch on open +
/// pull-to-refresh, no polling.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import 'tx_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TxSummary>? _txs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final wallet = context.read<WalletService>();
      final json = await wallet.fetchHistory();
      final list = json['transactions'] as List<dynamic>? ?? const [];
      setState(() {
        _txs = list.map((e) => TxSummary.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the network: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              )
            : _txs == null
                ? const Center(child: CircularProgressIndicator())
                : _txs!.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No transactions yet')),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _txs!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = _txs![i];
                          return ListTile(
                            leading: Icon(
                              t.isPending ? Icons.hourglass_empty : Icons.check_circle_outline,
                            ),
                            title: Text(
                              t.txid,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            subtitle: Text(t.isPending ? 'Pending' : 'Height ${t.height}'),
                            trailing: t.fee != null ? Text('fee ${t.fee}') : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => TxDetailScreen(txid: t.txid)),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
