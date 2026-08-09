/// On-device secure storage for the wallet's mnemonic seed.
///
/// This is the ONLY thing ever persisted -- no derived private keys are
/// cached to disk anywhere in this app; they're re-derived from the
/// mnemonic in memory each time they're needed and discarded afterward.
/// See docs/store-compliance.md for the platform-specific storage
/// guarantees (iOS Keychain device-only, no iCloud sync; Android
/// Keystore, hardware-backed where available).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletStorage {
  static const _mnemonicKey = 'cac_wallet_mnemonic_v1';
  static const _activeNetworkKey = 'cac_wallet_active_network_v1';
  static const _stakeTokenKey = 'cac_wallet_stake_token_v1';
  static const _addressIndicesKeyPrefix = 'cac_wallet_address_indices_v1_';
  static const _addressBookKey = 'cac_wallet_address_book_v1';
  static const _watchListKey = 'cac_wallet_watch_list_v1';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      // Device-only: never synced to iCloud Keychain. A wallet seed must
      // never leave this specific device via any sync mechanism.
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<bool> hasWallet() async {
    final value = await _storage.read(key: _mnemonicKey);
    return value != null && value.isNotEmpty;
  }

  Future<void> saveMnemonic(String mnemonic) async {
    await _storage.write(key: _mnemonicKey, value: mnemonic);
  }

  Future<String?> readMnemonic() => _storage.read(key: _mnemonicKey);

  /// Irreversible. Callers must confirm with the user before calling this
  /// -- there is no recovery without the mnemonic having been backed up
  /// elsewhere by the user themselves.
  Future<void> wipeWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _stakeTokenKey);
    await _storage.delete(key: '${_addressIndicesKeyPrefix}mainnet');
    await _storage.delete(key: '${_addressIndicesKeyPrefix}testnet');
    await _storage.delete(key: _addressBookKey);
    await _storage.delete(key: _watchListKey);
  }

  Future<void> saveActiveNetwork(String networkName) async {
    await _storage.write(key: _activeNetworkKey, value: networkName);
  }

  Future<String?> readActiveNetwork() => _storage.read(key: _activeNetworkKey);

  /// Every BIP44 index this wallet has generated on this device for
  /// [networkName], not a full gap-limit scan -- see the note on
  /// [WalletService.activeAddress]. Not secret (just bookkeeping for
  /// which derivation indices to re-derive), kept in the same secure
  /// storage as everything else here only to avoid adding a second
  /// storage dependency for one small integer list.
  Future<void> saveAddressIndices(String networkName, List<int> indices) async {
    await _storage.write(
      key: '$_addressIndicesKeyPrefix$networkName',
      value: jsonEncode(indices),
    );
  }

  Future<List<int>> readAddressIndices(String networkName) async {
    final raw = await _storage.read(key: '$_addressIndicesKeyPrefix$networkName');
    if (raw == null) return [0];
    final decoded = (jsonDecode(raw) as List).cast<int>();
    return decoded.isEmpty ? [0] : decoded;
  }

  /// Labelled addresses saved by the user for quick reuse in the send
  /// flow -- not secret, but kept alongside everything else for the same
  /// reason as address indices above.
  Future<void> saveAddressBook(List<Map<String, String>> entries) async {
    await _storage.write(key: _addressBookKey, value: jsonEncode(entries));
  }

  Future<List<Map<String, String>>> readAddressBook() async {
    final raw = await _storage.read(key: _addressBookKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => (e as Map).cast<String, String>())
        .toList();
  }

  /// Arbitrary addresses the user wants to monitor without holding their
  /// keys -- pure bookkeeping, same reasoning as address indices/book
  /// above for why this lives here instead of a separate storage plugin.
  Future<void> saveWatchList(List<Map<String, String>> entries) async {
    await _storage.write(key: _watchListKey, value: jsonEncode(entries));
  }

  Future<List<Map<String, String>>> readWatchList() async {
    final raw = await _storage.read(key: _watchListKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => (e as Map).cast<String, String>())
        .toList();
  }

  /// The staking-service auth token (see gateway_api.dart's login/signup).
  /// Distinct from the wallet's own on-chain keys -- this is a bearer
  /// token for the custodial gateway account, not derived from the
  /// mnemonic and not usable to move on-chain funds by itself.
  Future<void> saveStakeToken(String token) async {
    await _storage.write(key: _stakeTokenKey, value: token);
  }

  Future<String?> readStakeToken() => _storage.read(key: _stakeTokenKey);

  Future<void> clearStakeToken() async {
    await _storage.delete(key: _stakeTokenKey);
  }
}
