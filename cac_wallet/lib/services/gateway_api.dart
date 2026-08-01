/// HTTP client for the mobile API gateway specified in
/// ../../docs/mobile-api.md. That gateway does not exist yet as a running
/// service (Phase 4 was a specification only) -- every method here will
/// fail with a network error against a real endpoint until Phase 5/6
/// implements it. Kept as a single, narrow client class so swapping in
/// the real gateway later is a one-file change, and so this is the only
/// place in the app that does any networking beyond broadcasting a
/// transaction.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/network_config.dart';

class GatewayException implements Exception {
  final String code;
  final String message;
  GatewayException(this.code, this.message);
  @override
  String toString() => 'GatewayException($code): $message';
}

class GatewayApi {
  final NetworkConfig network;
  final http.Client _client;

  GatewayApi(this.network, {http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${network.gatewayBaseUrl}$path');

  Future<Map<String, dynamic>> _get(String path) async {
    final resp = await _client.get(_uri(path));
    return _decode(resp);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw GatewayException(
        error?['code'] as String? ?? 'unknown-error',
        error?['message'] as String? ?? 'Request failed (${resp.statusCode})',
      );
    }
    return decoded;
  }

  // -- §1 network status --
  Future<Map<String, dynamic>> networkStatus() => _get('/network/status');

  // -- §2 balance --
  Future<Map<String, dynamic>> balance(String address) =>
      _get('/address/$address/balance');

  // -- §3 UTXOs --
  Future<Map<String, dynamic>> utxos(String address) =>
      _get('/address/$address/utxos');

  // -- §4 history / tx detail / broadcast / fee estimate --
  Future<Map<String, dynamic>> history(String address, {int limit = 50}) =>
      _get('/address/$address/history?limit=$limit');

  Future<Map<String, dynamic>> transaction(String txid) => _get('/tx/$txid');

  Future<String> broadcast(String rawTxHex) async {
    final result = await _post('/tx/broadcast', {'raw_tx_hex': rawTxHex});
    return result['txid'] as String;
  }

  Future<Map<String, dynamic>> feeEstimate({int targetBlocks = 6}) =>
      _get('/fee-estimate?target_blocks=$targetBlocks');

  // -- §5 staking (Phase 6, no real backend yet -- calls will fail until
  // that phase exists; UI must handle GatewayException gracefully, never
  // crash on a missing staking backend) --
  Future<Map<String, dynamic>> stakingStatus(String authToken) => _get('/staking/status');

  Future<Map<String, dynamic>> stakingDeposit(int amountSatoshis) =>
      _post('/staking/deposit', {'amount': amountSatoshis.toString()});

  Future<Map<String, dynamic>> stakingWithdraw(int amountSatoshis, String toAddress) =>
      _post('/staking/withdraw', {
        'amount': amountSatoshis.toString(),
        'to_address': toAddress,
      });

  void close() => _client.close();
}
