/// On-device secure storage for the wallet's mnemonic seed.
///
/// This is the ONLY thing ever persisted -- no derived private keys are
/// cached to disk anywhere in this app; they're re-derived from the
/// mnemonic in memory each time they're needed and discarded afterward.
/// See docs/store-compliance.md for the platform-specific storage
/// guarantees (iOS Keychain device-only, no iCloud sync; Android
/// Keystore, hardware-backed where available).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletStorage {
  static const _mnemonicKey = 'cac_wallet_mnemonic_v1';
  static const _activeNetworkKey = 'cac_wallet_active_network_v1';

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
  }

  Future<void> saveActiveNetwork(String networkName) async {
    await _storage.write(key: _activeNetworkKey, value: networkName);
  }

  Future<String?> readActiveNetwork() => _storage.read(key: _activeNetworkKey);
}
