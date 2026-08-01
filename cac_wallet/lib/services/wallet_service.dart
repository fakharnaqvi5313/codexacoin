/// Ties together key derivation, secure storage, and the gateway API into
/// the app's single wallet state object.
///
/// NOTHING in this file, or anything it calls, performs mining, staking,
/// or any background/periodic computation -- see docs/store-compliance.md.
/// Every network call here is a single request/response HTTP call
/// initiated by explicit user action (opening a screen, tapping send).
library;

import 'package:flutter/foundation.dart';

import '../config/network_config.dart';
import '../crypto/address.dart';
import '../crypto/keys.dart';
import '../crypto/transaction.dart' as tx;
import 'gateway_api.dart';
import 'wallet_storage.dart';

class WalletService extends ChangeNotifier {
  final WalletStorage _storage = WalletStorage();
  GatewayApi _gateway = GatewayApi(NetworkConfig.mainnet);

  NetworkConfig network = NetworkConfig.mainnet;
  String? _mnemonic;
  bool loaded = false;

  bool get hasWallet => _mnemonic != null;

  Future<void> bootstrap() async {
    final storedNetwork = await _storage.readActiveNetwork();
    network = storedNetwork == 'testnet' ? NetworkConfig.testnet : NetworkConfig.mainnet;
    _gateway = GatewayApi(network);
    _mnemonic = await _storage.readMnemonic();
    loaded = true;
    notifyListeners();
  }

  Future<String> createNewWallet() async {
    final mnemonic = generateMnemonic();
    await _storage.saveMnemonic(mnemonic);
    _mnemonic = mnemonic;
    notifyListeners();
    return mnemonic;
  }

  Future<void> restoreWallet(String mnemonic) async {
    if (!isValidMnemonic(mnemonic)) {
      throw ArgumentError('Invalid recovery phrase');
    }
    await _storage.saveMnemonic(mnemonic);
    _mnemonic = mnemonic;
    notifyListeners();
  }

  Future<void> switchNetwork(CacNetwork n) async {
    network = NetworkConfig.forNetwork(n);
    _gateway = GatewayApi(network);
    await _storage.saveActiveNetwork(n == CacNetwork.testnet ? 'testnet' : 'mainnet');
    notifyListeners();
  }

  /// The wallet's single active receive address (account 0, external
  /// chain, index 0). A future revision should track a used-address set
  /// and advance the index per BIP44 convention; this phase keeps it to
  /// one address for simplicity, which is a real limitation worth calling
  /// out rather than silently deviating from BIP44 without saying so.
  String activeAddress() {
    final key = _requireKey();
    final hash = hash160(key.publicKey);
    return p2pkhAddress(hash, network);
  }

  DerivedKey _requireKey() {
    if (_mnemonic == null) {
      throw StateError('No wallet loaded');
    }
    return deriveKey(mnemonic: _mnemonic!, network: network, index: 0);
  }

  GatewayApi get gateway => _gateway;

  Future<Map<String, dynamic>> fetchBalance() => _gateway.balance(activeAddress());

  Future<Map<String, dynamic>> fetchHistory() => _gateway.history(activeAddress());

  /// Builds, signs, and broadcasts a send. [utxos] must already be known
  /// to belong to this wallet's active address (fetched via the gateway's
  /// UTXO endpoint by the caller) -- this method does not itself query
  /// anything beyond broadcasting the final signed transaction.
  Future<String> sendTransaction({
    required List<tx.Utxo> utxos,
    required String toAddress,
    required int amountSatoshis,
    required int feeSatoshis,
  }) async {
    final key = _requireKey();
    final decoded = decodeAddress(toAddress, network);
    final Uint8List outScript;
    switch (decoded.type) {
      case AddressType.p2pkh:
        outScript = tx.p2pkhScriptPubKey(decoded.hash);
      case AddressType.p2sh:
        outScript = tx.p2shScriptPubKey(decoded.hash);
      case AddressType.p2wpkh:
        outScript = tx.p2wpkhScriptPubKey(decoded.hash);
    }

    final totalIn = utxos.fold<int>(0, (sum, u) => sum + u.valueSatoshis);
    final change = totalIn - amountSatoshis - feeSatoshis;
    if (change < 0) {
      throw ArgumentError('Insufficient funds: have $totalIn, need ${amountSatoshis + feeSatoshis}');
    }

    final outputs = <tx.TxOutputSpec>[
      tx.TxOutputSpec(outScript, amountSatoshis),
      if (change > 0) tx.TxOutputSpec(tx.p2pkhScriptPubKey(hash160(key.publicKey)), change),
    ];

    final rawTx = tx.buildAndSignTransaction(
      inputs: utxos,
      outputs: outputs,
      privateKey: key.privateKey,
      publicKeyCompressed: key.publicKey,
    );

    final hex = rawTx.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _gateway.broadcast(hex);
  }

  /// Wipes the stored mnemonic. Irreversible -- the caller (UI layer)
  /// must have already confirmed this with the user via an explicit,
  /// unambiguous confirmation step before calling this.
  Future<void> wipeWallet() async {
    await _storage.wipeWallet();
    _mnemonic = null;
    notifyListeners();
  }
}
