// =========================
// lib/models/tx_status.dart
// =========================
class TxStatus {
  final String txid;
  final int confirmations;
  final bool inMempool;
  final String? blockhash;
  final int? blockHeight;
  final String? time;
  final String txType;

  const TxStatus({
    required this.txid,
    required this.confirmations,
    required this.inMempool,
    required this.blockhash,
    required this.blockHeight,
    required this.time,
    required this.txType,
  });

  factory TxStatus.fromJson(Map<String, dynamic> json) {
    return TxStatus(
      txid: (json['txid'] ?? '').toString(),
      confirmations: (json['confirmations'] ?? 0) as int,
      inMempool: (json['in_mempool'] ?? false) as bool,
      blockhash: json['blockhash'] as String?,
      blockHeight: json['block_height'] as int?,
      time: json['time'] as String?,
      txType: (json['tx_type'] ?? 'unknown').toString(),
    );
  }
}