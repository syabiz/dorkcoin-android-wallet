// =========================
// lib/services/api_service.dart
// Dorkcoin Explorer API v1 + ElectrumX for Dorkcoin
// API Docs: https://explorer.dorkcoin.org/api/
// =========================
import 'dart:convert';
import 'package:bs58/bs58.dart' as base58;
import 'package:convert/convert.dart' as convert;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/history_entry.dart';
import '../models/tx_status.dart';
import '../models/utxo.dart';
import 'electrumx_service.dart';

class ApiService {
  final String baseUrl;
  ElectrumXService? _electrumx;

  ApiService({this.baseUrl = AppConfig.apiBaseUrl});

  // Helper to handle response safely
  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (e) {
      throw Exception('Invalid server response: $body');
    }
  }

  // 1. Get Balance - Using /api/v1/balance/{address}
  Future<double> getBalance(String address) async {
    final uri = Uri.parse('$baseUrl/api/v1/balance/$address');
    if (kDebugMode) print('Fetching balance from: $uri');
    
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Failed to load balance: HTTP ${res.statusCode}');
    }
    try {
      return double.parse(res.body.trim());
    } catch (e) {
      throw Exception('Invalid balance response: ${res.body}');
    }
  }

  // 2. Get UTXOs - Using ElectrumX blockchain.scripthash.listunspent
  // Explorer API v1 doesn't have direct UTXO endpoint
  Future<List<Utxo>> getUtxos(String address) async {
    try {
      _electrumx ??= ElectrumXService();
      await _electrumx!.connect();
      
      // Convert address to scripthash for ElectrumX
      final scripthash = ElectrumXService.addressToScripthash(address);
      if (kDebugMode) print('Fetching UTXOs for scripthash: $scripthash');
      
      final utxoList = await _electrumx!.getUtxos(scripthash);
      _electrumx!.disconnect();
      
      if (kDebugMode) print('Found ${utxoList.length} UTXOs from ElectrumX');
      
      // Build scriptHex for the address
      final scriptHex = _buildP2pkhScriptPubKeyFromAddress(address);
      
      return utxoList.map((u) => Utxo(
        txid: u['tx_hash'] as String,
        vout: u['tx_pos'] as int,
        amount: (u['value'] as int) / 100000000.0, // ElectrumX returns satoshis
        scriptType: 'pubkeyhash',
        scriptHex: scriptHex,
        blockHeight: u['height'] as int?,
        confirmations: null, // Will be calculated from height
      )).toList();
    } catch (e) {
      if (kDebugMode) print('ElectrumX UTXO fetch failed: $e');
      // Fallback: return empty list - user can't spend but can see balance
      return [];
    }
  }

  // Build P2PKH scriptPubKey from address (fallback when API doesn't provide script)
  String _buildP2pkhScriptPubKeyFromAddress(String address) {
    // P2PKH scriptPubKey: OP_DUP OP_HASH160 <20 bytes pubkeyhash> OP_EQUALVERIFY OP_CHECKSIG
    // hex: 76a914<pubkeyhash>88ac
    try {
      // Use bs58 package to decode Base58Check address
      final decoded = base58.base58.decode(address);
      if (kDebugMode) {
        print('Decoded address $address: length=${decoded.length}, bytes=${convert.hex.encode(decoded)}');
      }
      if (decoded.length == 25) {
        // Format: [1 byte version][20 bytes pubkeyhash][4 bytes checksum]
        final pubkeyHash = decoded.sublist(1, 21);
        final scriptHex = '76a914${convert.hex.encode(pubkeyHash)}88ac';
        if (kDebugMode) {
          print('Generated scriptHex: $scriptHex');
        }
        return scriptHex;
      } else {
        if (kDebugMode) {
          print('Invalid decoded length: ${decoded.length}, expected 25');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error building scriptPubKey for $address: $e');
      }
    }
    // Return empty string - will be caught in tx_builder
    return '';
  }

  // 3. Get History - Using /api/v1/address/{address}
  // Returns: [{"txid": "...", "amount": "...", "direction": "received|sent", "timestamp": "..."}]
  Future<List<HistoryEntry>> getHistory(String address, {int page = 1, int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/api/v1/address/$address');

    if (kDebugMode) print('Fetching history from: $uri');

    final res = await http.get(uri).timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print('History response status: ${res.statusCode}');
    }

    if (res.statusCode != 200) {
      throw Exception('Failed to load transaction history: HTTP ${res.statusCode}');
    }

    final data = _safeJsonDecode(res.body);
    if (data == null) return [];
    if (data is! List) {
      if (data is Map && data['error'] != null) {
        throw Exception('API Error: ${data['error']}');
      }
      return [];
    }

    // Connect to ElectrumX for fetching transaction confirmations
    try {
      _electrumx ??= ElectrumXService();
      await _electrumx!.connect();
    } catch (e) {
      if (kDebugMode) print('Failed to connect to ElectrumX: $e');
    }

    final List<HistoryEntry> entries = [];

    for (final item in data) {
      if (item is! Map) continue;

      final txid = item['txid']?.toString();
      if (txid == null || txid.isEmpty) continue;

      // Parse amount and direction from API v1 response
      final amountStr = item['amount']?.toString() ?? '0';
      final amount = double.tryParse(amountStr) ?? 0.0;
      final direction = item['direction']?.toString() ?? 'received';
      final isReceive = direction == 'received';

      // Delta: positive = incoming, negative = outgoing
      final delta = isReceive ? amount : -amount;

      // Parse timestamp (format: "12-04-2026 04:39:28")
      final timestampStr = item['timestamp']?.toString() ?? '';

      if (kDebugMode) {
        print('History: txid=$txid, amount=$amount, direction=$direction, delta=$delta');
      }

      if (delta == 0) continue;

      // Fetch transaction details from ElectrumX (verbose=True returns confirmations)
      int? confirmations;
      int? blockHeight;
      try {
        if (_electrumx != null && _electrumx!.isConnected) {
          final txDetails = await _electrumx!.getTransaction(txid);
          // ElectrumX verbose response includes 'confirmations' field directly
          confirmations = txDetails['confirmations'] as int?;
          blockHeight = txDetails['blockheight'] as int? ?? txDetails['height'] as int?;
          if (kDebugMode) {
            print('TX $txid: confirmations=$confirmations, blockHeight=$blockHeight');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to get tx details for $txid: $e');
        }
      }

      entries.add(HistoryEntry(
        txid: txid,
        blockHeight: blockHeight,
        time: timestampStr,
        confirmations: confirmations,
        txType: isReceive ? 'receive' : 'send',
        role: isReceive ? 'receiver' : 'sender',
        delta: delta,
        otherAddress: '', // API v1 doesn't provide other address
      ));
    }

    // Disconnect ElectrumX when done
    _electrumx?.disconnect();

    return entries;
  }

  // 4. Send Transaction - Using ElectrumX blockchain.transaction.broadcast
  Future<String> sendRawTransaction(String rawHex) async {
    // Only use ElectrumX for broadcast (Explorer API v1 doesn't support broadcast)
    try {
      _electrumx ??= ElectrumXService();
      await _electrumx!.connect();
      
      if (kDebugMode) {
        print('Broadcasting transaction via ElectrumX...');
        print('Raw tx hex length: ${rawHex.length}');
      }
      
      final txid = await _electrumx!.broadcastTransaction(rawHex);
      _electrumx!.disconnect();
      
      if (kDebugMode) print('Broadcast successful! TXID: $txid');
      return txid;
    } catch (e) {
      if (kDebugMode) print('ElectrumX broadcast error: $e');
      
      // Provide helpful error message
      String errorMsg = e.toString();
      if (errorMsg.contains('404') || errorMsg.contains('Not Found')) {
        throw Exception('Transaction broadcast failed: The ElectrumX server is not responding. Please check your internet connection and try again.');
      } else if (errorMsg.contains('mempool') || errorMsg.contains('reject')) {
        throw Exception('Transaction rejected by network: The transaction may be invalid or there may be insufficient fees.');
      } else if (errorMsg.contains('timeout') || errorMsg.contains('Socket')) {
        throw Exception('Connection timeout: Could not connect to ElectrumX server. Please try again later.');
      }
      throw Exception('Broadcast failed: $errorMsg');
    }
  }
  
  /// Dispose ElectrumX connection
  void dispose() {
    _electrumx?.dispose();
    _electrumx = null;
  }

  Future<Map<String, dynamic>> testMempoolAccept(String rawHex) async {
    // Try to validate transaction format locally
    // Basic check: raw hex should be even length and valid hex
    if (rawHex.length % 2 != 0 || !RegExp(r'^[a-fA-F0-9]+$').hasMatch(rawHex)) {
      return {'allowed': false, 'reject-reason': 'Invalid transaction hex format'};
    }
    // Minimum transaction size check (at least version + input count + output count + locktime)
    if (rawHex.length < 20) {
      return {'allowed': false, 'reject-reason': 'Transaction too small'};
    }
    // For now, we can't actually test mempool acceptance without a node
    // Return true to allow broadcast attempt
    return {'allowed': true};
  }

  Future<TxStatus> getTxStatus(String txid) async {
    // Use ElectrumX to get transaction status
    try {
      _electrumx ??= ElectrumXService();
      await _electrumx!.connect();

      if (kDebugMode) print('Fetching TX status from ElectrumX for: $txid');

      // Get transaction details (verbose=True returns confirmations field)
      final txDetails = await _electrumx!.getTransaction(txid);

      // ElectrumX verbose response includes 'confirmations' field directly
      final confirmations = txDetails['confirmations'] as int? ?? 0;
      final blockHeight = txDetails['blockheight'] as int? ?? txDetails['height'] as int?;

      if (kDebugMode) {
        print('TX $txid: confirmations=$confirmations, blockHeight=$blockHeight');
      }

      _electrumx!.disconnect();

      return TxStatus(
        txid: txid,
        confirmations: confirmations,
        inMempool: confirmations == 0, // If 0 confirmations, it's in mempool
        blockhash: txDetails['blockhash'] as String?,
        blockHeight: blockHeight,
        time: txDetails['time']?.toString() ?? '',
        txType: 'standard',
      );
    } catch (e) {
      if (kDebugMode) print('Failed to get TX status from ElectrumX: $e');
      throw Exception('Failed to load TX status: $e');
    }
  }
}
