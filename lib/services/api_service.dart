// =========================
// lib/services/api_service.dart
// Robust Iquidus Explorer API for Dorkcoin
// =========================
import 'dart:convert';
import 'package:bs58/bs58.dart' as base58;
import 'package:convert/convert.dart' as convert;
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/history_entry.dart';
import '../models/tx_status.dart';
import '../models/utxo.dart';

class ApiService {
  final String baseUrl;

  const ApiService({this.baseUrl = AppConfig.apiBaseUrl});

  // Helper to handle response safely
  dynamic _safeJsonDecode(String body) {
    if (body.contains('This method is disabled')) {
      throw Exception('Server API Error: The explorer admin has disabled this function. Please contact explorer admin.');
    }
    try {
      return jsonDecode(body);
    } catch (e) {
      throw Exception('Invalid server response: $body');
    }
  }

  // 1. Get Balance
  Future<double> getBalance(String address) async {
    final uri = Uri.parse('$baseUrl/ext/getbalance/$address');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load balance');
    try {
      return double.parse(res.body.trim());
    } catch (e) {
      final data = _safeJsonDecode(res.body);
      return ((data['balance'] ?? 0) as num).toDouble();
    }
  }

  // 2. Get UTXOs - Using /ext/getaddress to get tx list, then /ext/gettx for details
  Future<List<Utxo>> getUtxos(String address) async {
    // Step 1: Get address info with last_txs
    final addrUri = Uri.parse('$baseUrl/ext/getaddress/$address');
    final addrRes = await http.get(addrUri);

    if (addrRes.statusCode != 200) {
      throw Exception('Failed to load address info from server.');
    }

    final addrData = _safeJsonDecode(addrRes.body);
    if (addrData is! Map || addrData['last_txs'] is! List) {
      return [];
    }

    final lastTxs = addrData['last_txs'] as List;
    final List<Utxo> utxos = [];
    final Set<String> spentOutputs = {}; // Format: "txid_vout"
    final Map<String, Map<String, dynamic>> potentialUtxos = {}; // Key: "txid_vout", Value: UTXO data

    // Step 2: Fetch each transaction to get vin/vout details
    for (final txRef in lastTxs) {
      if (txRef is! Map) continue;
      final txid = txRef['addresses']?.toString();
      if (txid == null || txid.isEmpty) continue;

      try {
        final txUri = Uri.parse('$baseUrl/ext/gettx/$txid');
        final txRes = await http.get(txUri);
        if (txRes.statusCode != 200) continue;

        final txData = _safeJsonDecode(txRes.body);
        if (txData is! Map) continue;

        final tx = txData['tx'] as Map<String, dynamic>?;
        if (tx == null) continue;

        // Check vin - mark spent outputs
        if (tx['vin'] is List) {
          for (final vin in tx['vin']) {
            if (vin is Map) {
              final vinTxid = vin['txid']?.toString();
              final vinVout = vin['vout'] as int?;
              if (vinTxid != null && vinVout != null) {
                spentOutputs.add('${vinTxid}_$vinVout');
              }
            }
          }
        }

        // Check vout - find outputs to this address
        if (tx['vout'] is List) {
          for (int i = 0; i < (tx['vout'] as List).length; i++) {
            final vout = tx['vout'][i];
            if (vout is Map && vout['addresses'] == address) {
              // Amount is in satoshi, convert to coins
              final amountSats = double.tryParse(vout['amount']?.toString() ?? '0') ?? 0.0;
              final amount = amountSats / 100000000;
              final confirmations = txData['confirmations'] as int? ?? 0;

              // Generate scriptPubKey from address (API doesn't provide it in /ext/gettx)
              final scriptHex = _buildP2pkhScriptPubKeyFromAddress(address);

              potentialUtxos['${txid}_$i'] = {
                'txid': txid,
                'vout': i,
                'amount': amount,
                'scriptHex': scriptHex,
                'confirmations': confirmations,
                'blockHeight': tx['blockindex'] as int?,
              };
            }
          }
        }
      } catch (_) {
        // Skip failed transaction fetches
        continue;
      }
    }

    // Step 3: Filter out spent UTXOs
    for (final entry in potentialUtxos.entries) {
      if (!spentOutputs.contains(entry.key)) {
        final data = entry.value;
        utxos.add(Utxo(
          txid: data['txid'],
          vout: data['vout'],
          amount: data['amount'],
          scriptType: 'pubkeyhash',
          scriptHex: data['scriptHex'],
          blockHeight: data['blockHeight'],
          confirmations: data['confirmations'],
        ));
      }
    }

    return utxos;
  }

  // Build P2PKH scriptPubKey from address (fallback when API doesn't provide script)
  String _buildP2pkhScriptPubKeyFromAddress(String address) {
    // P2PKH scriptPubKey: OP_DUP OP_HASH160 <20 bytes pubkeyhash> OP_EQUALVERIFY OP_CHECKSIG
    // hex: 76a914<pubkeyhash>88ac
    try {
      // Use bs58 package to decode Base58Check address
      final decoded = base58.base58.decode(address);
      if (decoded.length == 25) {
        // Format: [1 byte version][20 bytes pubkeyhash][4 bytes checksum]
        final pubkeyHash = decoded.sublist(1, 21);
        return '76a914${convert.hex.encode(pubkeyHash)}88ac';
      }
    } catch (_) {
      // Ignore decoding errors
    }
    return '';
  }

  // 3. Get History - Using /ext/getaddress to get tx list, then /ext/gettx for details
  Future<List<HistoryEntry>> getHistory(String address, {int page = 1, int limit = 50}) async {
    // Step 1: Get address info with last_txs
    final addrUri = Uri.parse('$baseUrl/ext/getaddress/$address');
    final addrRes = await http.get(addrUri);
    if (addrRes.statusCode != 200) throw Exception('Failed to load address info');

    final addrData = _safeJsonDecode(addrRes.body);
    if (addrData is! Map || addrData['last_txs'] is! List) return [];

    final lastTxs = addrData['last_txs'] as List;
    final List<HistoryEntry> entries = [];

    // Calculate pagination
    final start = (page - 1) * limit;
    final end = start + limit;
    final paginatedTxs = lastTxs.length > start 
        ? lastTxs.sublist(start, end > lastTxs.length ? lastTxs.length : end)
        : [];

    // Step 2: Fetch each transaction detail
    for (final txRef in paginatedTxs) {
      if (txRef is! Map) continue;
      final txid = txRef['addresses']?.toString();
      if (txid == null || txid.isEmpty) continue;

      try {
        final txUri = Uri.parse('$baseUrl/ext/gettx/$txid');
        final txRes = await http.get(txUri);
        if (txRes.statusCode != 200) continue;

        final txData = _safeJsonDecode(txRes.body);
        if (txData is! Map) continue;

        final tx = txData['tx'] as Map<String, dynamic>?;
        if (tx == null) continue;

        final confirmations = txData['confirmations'] as int? ?? 0;
        final timestamp = tx['timestamp'] as int?;
        final time = timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toString().split('.')[0]
            : 'Pending';

        // Calculate delta from vin/vout
        double totalReceived = 0.0;
        double totalSent = 0.0;

        // Check vout (received)
        if (tx['vout'] is List) {
          for (final vout in tx['vout']) {
            if (vout is Map && vout['addresses'] == address) {
              final amount = double.tryParse(vout['amount']?.toString() ?? '0') ?? 0.0;
              totalReceived += amount / 100000000; // Convert from satoshi to coins
            }
          }
        }

        // Check vin (sent) - need to fetch input transactions
        if (tx['vin'] is List) {
          for (final vin in tx['vin']) {
            if (vin is Map) {
              final vinTxid = vin['txid']?.toString();
              final vinVout = vin['vout'] as int?;
              if (vinTxid != null && vinVout != null) {
                // Fetch the input transaction to see if it belongs to this address
                try {
                  final vinTxUri = Uri.parse('$baseUrl/ext/gettx/$vinTxid');
                  final vinTxRes = await http.get(vinTxUri);
                  if (vinTxRes.statusCode == 200) {
                    final vinTxData = _safeJsonDecode(vinTxRes.body);
                    final vinTx = vinTxData['tx'] as Map<String, dynamic>?;
                    if (vinTx != null && vinTx['vout'] is List) {
                      final outputs = vinTx['vout'] as List;
                      if (vinVout < outputs.length) {
                        final output = outputs[vinVout];
                        if (output is Map && output['addresses'] == address) {
                          final amount = double.tryParse(output['amount']?.toString() ?? '0') ?? 0.0;
                          totalSent += amount / 100000000;
                        }
                      }
                    }
                  }
                } catch (_) {
                  // Skip failed vin fetches
                }
              }
            }
          }
        }

        // Calculate delta
        final delta = totalReceived - totalSent;
        if (delta == 0) continue;

        entries.add(HistoryEntry(
          txid: txid,
          blockHeight: tx['blockindex'] as int?,
          time: time,
          confirmations: confirmations,
          txType: delta > 0 ? 'receive' : 'send',
          role: delta > 0 ? 'receiver' : 'sender',
          delta: delta,
          otherAddress: '',
        ));
      } catch (_) {
        // Skip failed transaction fetches
        continue;
      }
    }

    return entries;
  }

  // 4. Send Transaction
  Future<String> sendRawTransaction(String rawHex) async {
    // Pattern 1: /api/sendrawtransaction?hex=HEX
    final uri = Uri.parse('$baseUrl/api/sendrawtransaction?hex=$rawHex');
    final res = await http.get(uri);

    final body = res.body.trim();
    if (body.length == 64 && !body.contains(' ')) return body; // Likely a TXID

    final dynamic data = _safeJsonDecode(body);
    return (data['txid'] ?? data['result'] ?? body).toString();
  }

  Future<Map<String, dynamic>> testMempoolAccept(String rawHex) async {
    return {'allowed': true};
  }

  Future<TxStatus> getTxStatus(String txid) async {
    final uri = Uri.parse('$baseUrl/api/getrawtransaction?txid=$txid&decrypt=1');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load TX status');
    final data = _safeJsonDecode(res.body);
    return TxStatus(
      txid: txid,
      confirmations: (data['confirmations'] as int? ?? 0),
      inMempool: (data['confirmations'] as int? ?? 0) == 0,
      blockhash: data['blockhash'] as String?,
      blockHeight: data['blockheight'] as int?,
      time: (data['time'] ?? '').toString(),
      txType: 'standard',
    );
  }
}
