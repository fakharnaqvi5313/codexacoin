// xpub.dart's public (non-hardened) child derivation must produce the
// exact same addresses as the wallet's own private-key derivation path
// -- that's the entire point of watch-only-via-xpub, so these tests
// check real address equality, not just "it doesn't throw".
import 'package:cac_wallet/config/network_config.dart';
import 'package:cac_wallet/crypto/address.dart';
import 'package:cac_wallet/crypto/keys.dart';
import 'package:cac_wallet/crypto/xpub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('address derived via xpub matches the same index derived from the private key', () {
    final xpub = deriveAccountXpub(mnemonic: testMnemonic, network: NetworkConfig.mainnet);
    for (var index = 0; index < 3; index++) {
      final viaXpub = deriveXpubAddress(xpub: xpub, network: NetworkConfig.mainnet, index: index);
      final directKey = deriveKey(mnemonic: testMnemonic, network: NetworkConfig.mainnet, index: index);
      final directAddress = p2pkhAddress(hash160(directKey.publicKey), NetworkConfig.mainnet);
      expect(viaXpub, directAddress);
    }
  });

  test('importing a mainnet xpub while asking for testnet fails closed', () {
    final xpub = deriveAccountXpub(mnemonic: testMnemonic, network: NetworkConfig.mainnet);
    expect(
      () => deriveXpubAddress(xpub: xpub, network: NetworkConfig.testnet, index: 0),
      throwsArgumentError,
    );
  });

  // Golden vector captured live from web-wallet/crypto.js's
  // deriveAccountXpub with the same testMnemonic -- confirms the two
  // independently hand-configured BIP32 version-byte setups actually
  // agree on the exact xpub string, not just that each is internally
  // self-consistent.
  test('matches the exact xpub produced by web-wallet/crypto.js for the same mnemonic', () {
    const webXpub =
        'xpub6DAGTSGNsUrmJn25ZsR7Uph8rPfoMaZUhfabTUpXrX6BCYbvYF1G8v8tmnwkS6bRQ5RvBzX1CfKYhVUUDpKvbeFL5czfwJqeTZf14VHp8A9';
    final xpub = deriveAccountXpub(mnemonic: testMnemonic, network: NetworkConfig.mainnet);
    expect(xpub, webXpub);
    // ...and the addresses it derives match the ones captured from the
    // web side's deriveXpubAddress for the same xpub/indices.
    expect(deriveXpubAddress(xpub: webXpub, network: NetworkConfig.mainnet, index: 0),
        'CR5bRdhR65DTDyBJMTdQs4VrYePG9XmDz7');
    expect(deriveXpubAddress(xpub: webXpub, network: NetworkConfig.mainnet, index: 1),
        'CfjPtDscbQLQ9FPPvRv5eHv7hehrCsGPD5');
    expect(deriveXpubAddress(xpub: webXpub, network: NetworkConfig.mainnet, index: 2),
        'CYZj6UPAUWcSAUFtbnFywpKuz79RM9Yg5r');
  });
}
