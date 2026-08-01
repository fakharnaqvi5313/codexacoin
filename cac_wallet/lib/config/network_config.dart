/// CodexaCoin network parameters. Values taken directly from
/// PARAMETERS.md at the CodexaCloud repo root -- do not hand-edit these
/// without updating that file too, it's the single source of truth.
library;

enum CacNetwork { mainnet, testnet }

class NetworkConfig {
  final CacNetwork network;
  final String name;

  /// Base58Check version byte for P2PKH addresses.
  final int p2pkhVersion;

  /// Base58Check version byte for P2SH addresses.
  final int p2shVersion;

  /// Base58Check version byte for WIF-encoded private keys.
  final int wifVersion;

  /// bech32 human-readable part for P2WPKH/P2WSH addresses.
  final String bech32Hrp;

  /// BIP44 coin type for HD derivation (m/44'/coinType'/...).
  /// CAC uses 3377 (unregistered placeholder -- see PARAMETERS.md section
  /// 2 TODO) on mainnet, and the SLIP-44-standard testnet index 1 on
  /// testnet, matching convention (every coin's testnet uses coin_type=1).
  final int bip44CoinType;

  /// Gateway API base URL (see ../../docs/mobile-api.md). Placeholder --
  /// no real gateway/infra exists yet (Phase 4 was a specification only).
  final String gatewayBaseUrl;

  const NetworkConfig._({
    required this.network,
    required this.name,
    required this.p2pkhVersion,
    required this.p2shVersion,
    required this.wifVersion,
    required this.bech32Hrp,
    required this.bip44CoinType,
    required this.gatewayBaseUrl,
  });

  static const mainnet = NetworkConfig._(
    network: CacNetwork.mainnet,
    name: 'CodexaCoin Mainnet',
    p2pkhVersion: 0x1c, // 28 -> 'C...' addresses
    p2shVersion: 0x3f, // 63 -> 'S...' addresses
    wifVersion: 0x9c, // 156
    bech32Hrp: 'cac',
    bip44CoinType: 3377,
    gatewayBaseUrl: 'https://api.codexacoin.example/v1',
  );

  static const testnet = NetworkConfig._(
    network: CacNetwork.testnet,
    name: 'CodexaCoin Testnet',
    p2pkhVersion: 0x6f, // 111 -- inherited Bitcoin-standard testnet value
    p2shVersion: 0xc4, // 196
    wifVersion: 0xef, // 239
    bech32Hrp: 'tcac',
    bip44CoinType: 1, // SLIP-44 standard "testnet" index, all coins share this
    gatewayBaseUrl: 'https://testnet-api.codexacoin.example/v1',
  );

  static NetworkConfig forNetwork(CacNetwork n) =>
      n == CacNetwork.mainnet ? mainnet : testnet;
}
