// =========================
// lib/models/wallet_info.dart
// =========================
class WalletInfo {
  final String address;
  final String wif;
  final String privateKeyHex;
  final String publicKeyHex;

  const WalletInfo({
    required this.address,
    required this.wif,
    required this.privateKeyHex,
    required this.publicKeyHex,
  });
}