// =========================
// lib/models/utxo.dart
// =========================
class Utxo {
  final String txid;
  final int vout;
  final double amount;
  final String scriptType;
  final String scriptHex;
  final int? blockHeight;
  final int? confirmations;

  int get valueSats => (amount * 100000000).round();

  const Utxo({
    required this.txid,
    required this.vout,
    required this.amount,
    required this.scriptType,
    required this.scriptHex,
    required this.blockHeight,
    required this.confirmations,
  });

  factory Utxo.fromJson(Map<String, dynamic> json) {
    return Utxo(
      txid: (json['txid'] ?? '').toString(),
      vout: (json['vout'] ?? 0) as int,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      scriptType: (json['script_type'] ?? 'unknown').toString(),
      scriptHex: (json['script_hex'] ?? '').toString(),
      blockHeight: json['block_height'] as int?,
      confirmations: json['confirmations'] as int?,
    );
  }
}
