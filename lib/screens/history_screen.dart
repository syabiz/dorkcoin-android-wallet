// =========================
// lib/screens/history_screen.dart
// =========================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/history_entry.dart';
import '../services/api_service.dart';

class _HistoryGroup {
  final String txid;
  final String time;
  final double delta;
  final int? confirmations;

  const _HistoryGroup({
    required this.txid,
    required this.time,
    required this.delta,
    required this.confirmations,
  });
}

class HistoryScreen extends StatefulWidget {
  final String address;

  const HistoryScreen({super.key, required this.address});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  List<HistoryEntry> _rows = const [];

  List<_HistoryGroup> _groupRowsByTxid(List<HistoryEntry> rows) {
    final grouped = <String, _HistoryGroup>{};

    for (final row in rows) {
      final existing = grouped[row.txid];
      if (existing == null) {
        grouped[row.txid] = _HistoryGroup(
          txid: row.txid,
          time: row.time,
          delta: row.delta,
          confirmations: row.confirmations,
        );
      } else {
        grouped[row.txid] = _HistoryGroup(
          txid: existing.txid,
          time: existing.time,
          delta: existing.delta + row.delta,
          confirmations: (row.confirmations ?? 0) > (existing.confirmations ?? 0)
              ? row.confirmations
              : existing.confirmations,
        );
      }
    }

    return grouped.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _api.getHistory(widget.address);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isOutgoing(double delta) => delta < 0;

  Color _deltaColor(BuildContext context, double delta) {
    return _isOutgoing(delta) ? Colors.redAccent : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : Builder(
                    builder: (context) {
                      final groupedRows = _groupRowsByTxid(_rows);
                      return ListView.separated(
                        itemCount: groupedRows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = groupedRows[index];
                          final isOutgoing = _isOutgoing(row.delta);
                          final deltaColor = _deltaColor(context, row.delta);
                          final deltaPrefix = isOutgoing ? '-' : '+';

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: deltaColor.withValues(alpha: 0.14),
                                child: Icon(
                                  isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: deltaColor,
                                ),
                              ),
                              title: Text(
                                '$deltaPrefix${row.delta.abs().toStringAsFixed(8)} DORK',
                                style: TextStyle(
                                  color: deltaColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(row.time),
                                  const SizedBox(height: 4),
                                  Text('Confirmations: ${row.confirmations?.toString() ?? '-'}'),
                                  const SizedBox(height: 4),
                                  SelectableText(row.txid),
                                ],
                              ),
                              trailing: IconButton(
                                tooltip: 'Copy TXID',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: row.txid));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('TXID copied to clipboard.')),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
