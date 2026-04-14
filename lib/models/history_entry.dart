// =========================
// lib/models/history_entry.dart
// =========================
class HistoryEntry {
  final String txid;
  final int? blockHeight;
  final String time;
  final int? confirmations;
  final String txType;
  final String role;
  final double delta;
  final String otherAddress;

  const HistoryEntry({
    required this.txid,
    required this.blockHeight,
    required this.time,
    required this.confirmations,
    required this.txType,
    required this.role,
    required this.delta,
    required this.otherAddress,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      txid: (json['txid'] ?? '').toString(),
      blockHeight: json['block_height'] as int?,
      time: (json['time'] ?? '').toString(),
      confirmations: json['confirmations'] as int?,
      txType: (json['tx_type'] ?? 'unknown').toString(),
      role: (json['role'] ?? 'unknown').toString(),
      delta: ((json['delta'] ?? 0) as num).toDouble(),
      otherAddress: (json['other_address'] ?? '').toString(),
    );
  }
}
