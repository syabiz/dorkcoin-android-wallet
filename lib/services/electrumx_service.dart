// =========================
// lib/services/electrumx_service.dart
// ElectrumX Client for Dorkcoin
// =========================
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';

/// ElectrumX JSON-RPC client using TCP socket
/// Note: Port 50002 typically uses SSL/TLS. This implementation uses plain TCP.
/// For production SSL support, use SecureSocket.
class ElectrumXService {
  final String host;
  final int port;
  final bool useSsl;
  
  Socket? _socket;
  StreamSubscription? _subscription;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  int _requestId = 0;
  final _buffer = StringBuffer();
  
  bool _isConnected = false;
  
  ElectrumXService({
    this.host = AppConfig.electrumHost,
    this.port = AppConfig.electrumPort,
    this.useSsl = AppConfig.electrumUseSsl,
  });
  
  bool get isConnected => _isConnected;
  
  /// Connect to ElectrumX server
  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      if (kDebugMode) {
        print('ElectrumX: Connecting to $host:$port (SSL: $useSsl)');
      }
      
      // Port 50002 uses SSL/TLS
      if (useSsl || port == 50002) {
        if (kDebugMode) print('ElectrumX: Using SecureSocket');
        _socket = await SecureSocket.connect(
          host, 
          port, 
          timeout: const Duration(seconds: 10),
          onBadCertificate: (certificate) {
            if (kDebugMode) {
              print('ElectrumX: Certificate subject: ${certificate.subject}');
              print('ElectrumX: Accepting bad certificate');
            }
            return true;
          },
        );
      } else {
        if (kDebugMode) print('ElectrumX: Using plain Socket');
        _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      }
      
      if (kDebugMode) print('ElectrumX: Socket connected');
      
      // Listen for responses
      _subscription = _socket!.cast<List<int>>().transform(utf8.decoder).listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );
      
      _isConnected = true;
      if (kDebugMode) print('ElectrumX: Listening for responses');
      
      // Send server version request to verify connection
      if (kDebugMode) print('ElectrumX: Sending server.version');
      final version = await _call('server.version', ['Dorkcoin Wallet', '1.4']);
      if (kDebugMode) print('ElectrumX: Server version: $version');
      
    } catch (e) {
      if (kDebugMode) print('ElectrumX: Connection error: $e');
      _cleanup();
      throw Exception('Failed to connect to ElectrumX: $e');
    }
  }
  
  /// Disconnect from server
  void disconnect() {
    _cleanup();
  }
  
  void _cleanup() {
    _isConnected = false;
    _subscription?.cancel();
    _socket?.destroy();
    _socket = null;
    _buffer.clear();
    
    // Complete all pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection closed'));
      }
    }
    _pendingRequests.clear();
  }
  
  void _handleData(String data) {
    _buffer.write(data);
    
    // Process complete lines (JSON-RPC responses end with newline)
    while (true) {
      final bufferStr = _buffer.toString();
      final newlineIndex = bufferStr.indexOf('\n');
      if (newlineIndex == -1) break;
      
      final line = bufferStr.substring(0, newlineIndex).trim();
      _buffer.clear();
      if (newlineIndex + 1 < bufferStr.length) {
        _buffer.write(bufferStr.substring(newlineIndex + 1));
      }
      
      if (line.isEmpty) continue;
      
      try {
        final response = jsonDecode(line) as Map<String, dynamic>;
        final id = response['id'] as int?;
        
        if (id != null && _pendingRequests.containsKey(id)) {
          final completer = _pendingRequests.remove(id)!;
          if (!completer.isCompleted) {
            if (response.containsKey('error') && response['error'] != null) {
              final error = response['error'];
              if (error is Map) {
                final message = error['message']?.toString() ?? error.toString();
                completer.completeError(Exception('ElectrumX Error: $message'));
              } else {
                completer.completeError(Exception('ElectrumX Error: $error'));
              }
            } else {
              completer.complete(response['result']);
            }
          }
        }
      } catch (e) {
        // Ignore parsing errors for malformed responses
        if (kDebugMode) {
          print('ElectrumX parse error: $e, line: $line');
        }
      }
    }
  }
  
  void _handleError(error) {
    if (kDebugMode) {
      print('ElectrumX socket error: $error');
    }
    _cleanup();
  }
  
  void _handleDone() {
    if (kDebugMode) {
      print('ElectrumX socket closed');
    }
    _cleanup();
  }
  
  /// Make a JSON-RPC call to ElectrumX
  Future<dynamic> _call(String method, List<dynamic> params) async {
    if (!_isConnected) {
      throw Exception('Not connected to ElectrumX server');
    }
    
    final id = ++_requestId;
    final request = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': id,
    };
    
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;
    
    final jsonRequest = '${jsonEncode(request)}\n';
    _socket!.write(jsonRequest);
    
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw Exception('Request timeout: $method');
      },
    );
  }
  
  // =========================
  // ElectrumX API Methods
  // =========================
  
  /// Get server features and version
  Future<Map<String, dynamic>> getServerFeatures() async {
    return await _call('server.features', []) as Map<String, dynamic>;
  }
  
  /// Get balance for an address (scripthash)
  /// Returns confirmed and unconfirmed balance in satoshis
  Future<Map<String, int>> getBalance(String scripthash) async {
    final result = await _call('blockchain.scripthash.get_balance', [scripthash]) as Map<String, dynamic>;
    return {
      'confirmed': result['confirmed'] as int? ?? 0,
      'unconfirmed': result['unconfirmed'] as int? ?? 0,
    };
  }
  
  /// Get UTXOs for an address (scripthash)
  Future<List<Map<String, dynamic>>> getUtxos(String scripthash) async {
    final result = await _call('blockchain.scripthash.listunspent', [scripthash]) as List<dynamic>;
    return result.map((e) => e as Map<String, dynamic>).toList();
  }
  
  /// Get transaction history for an address (scripthash)
  Future<List<Map<String, dynamic>>> getHistory(String scripthash) async {
    final result = await _call('blockchain.scripthash.get_history', [scripthash]) as List<dynamic>;
    return result.map((e) => e as Map<String, dynamic>).toList();
  }
  
  /// Get raw transaction by txid
  Future<String> getRawTransaction(String txid) async {
    return await _call('blockchain.transaction.get', [txid, false]) as String;
  }
  
  /// Get transaction by txid (verbose)
  Future<Map<String, dynamic>> getTransaction(String txid) async {
    return await _call('blockchain.transaction.get', [txid, true]) as Map<String, dynamic>;
  }
  
  /// Get transaction merkle proof
  Future<Map<String, dynamic>> getMerkle(String txid, int height) async {
    return await _call('blockchain.transaction.get_merkle', [txid, height]) as Map<String, dynamic>;
  }
  
  /// BROADCAST TRANSACTION - The key method we need!
  /// Returns the txid if successful
  Future<String> broadcastTransaction(String rawTxHex) async {
    try {
      final result = await _call('blockchain.transaction.broadcast', [rawTxHex]);
      
      // Result should be the txid
      if (result is String) {
        // Validate txid format (64 hex characters)
        if (result.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(result)) {
          return result;
        }
        throw Exception('Invalid TXID format returned: $result');
      } else if (result is Map && result.containsKey('txid')) {
        final txid = result['txid'] as String;
        if (txid.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(txid)) {
          return txid;
        }
        throw Exception('Invalid TXID format returned: $txid');
      } else {
        throw Exception('Unexpected response format: $result');
      }
    } catch (e) {
      throw Exception('Broadcast failed: $e');
    }
  }
  
  /// Get current block height
  Future<int> getBlockHeight() async {
    final result = await _call('blockchain.headers.subscribe', []);
    if (result is Map && result.containsKey('height')) {
      return result['height'] as int;
    }
    throw Exception('Invalid response format for block height');
  }
  
  /// Get block header by height
  Future<String> getBlockHeader(int height) async {
    return await _call('blockchain.block.header', [height]) as String;
  }
  
  /// Estimate fee for transaction (returns DORK per KB)
  Future<double> estimateFee(int numBlocks) async {
    final result = await _call('blockchain.estimatefee', [numBlocks]);
    if (result is num) {
      return result.toDouble();
    }
    throw Exception('Invalid fee estimate response');
  }
  
  /// Subscribe to address notifications (scripthash)
  /// Returns the current status hash of the scripthash
  Future<String> subscribeToAddress(String scripthash) async {
    return await _call('blockchain.scripthash.subscribe', [scripthash]) as String;
  }
  
  // =========================
  // Utility Methods
  // =========================
  
  /// Convert address to scripthash (required by ElectrumX)
  /// Address -> ScriptPubKey -> SHA256 -> Reverse bytes -> Hex
  static String addressToScripthash(String address) {
    // First, decode the address to get the scriptPubKey
    final scriptPubKey = _addressToScriptPubKey(address);
    
    // SHA256 hash
    final hash = _sha256(scriptPubKey);
    
    // Reverse byte order (little endian)
    final reversed = hash.reversed.toList();
    
    return hex.encode(reversed);
  }
  
  /// Convert P2PKH address to scriptPubKey
  static List<int> _addressToScriptPubKey(String address) {
    // Base58 decode
    final decoded = _base58Decode(address);
    
    // P2PKH scriptPubKey: OP_DUP OP_HASH160 <20 bytes pubkeyhash> OP_EQUALVERIFY OP_CHECKSIG
    // 0x76 0xa9 0x14 <20 bytes> 0x88 0xac
    
    if (decoded.length < 21) {
      throw Exception('Invalid address');
    }
    
    // Extract pubkeyhash (skip version byte, take 20 bytes)
    final pubkeyHash = decoded.sublist(1, 21);
    
    return [
      0x76, // OP_DUP
      0xa9, // OP_HASH160
      0x14, // push 20 bytes
      ...pubkeyHash,
      0x88, // OP_EQUALVERIFY
      0xac, // OP_CHECKSIG
    ];
  }
  
  /// Simple Base58 decode (for address conversion)
  static List<int> _base58Decode(String encoded) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    
    BigInt value = BigInt.zero;
    for (final codePoint in encoded.runes) {
      final ch = String.fromCharCode(codePoint);
      final index = alphabet.indexOf(ch);
      if (index < 0) {
        throw Exception('Invalid Base58 character: $ch');
      }
      value = value * BigInt.from(58) + BigInt.from(index);
    }
    
    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.add((value & BigInt.from(0xff)).toInt());
      value = value >> 8;
    }
    final decoded = bytes.reversed.toList();
    
    int leadingOnes = 0;
    while (leadingOnes < encoded.length && encoded[leadingOnes] == '1') {
      leadingOnes++;
    }
    
    return [
      ...List<int>.filled(leadingOnes, 0),
      ...decoded,
    ];
  }
  
  /// SHA256 hash
  static List<int> _sha256(List<int> data) {
    final digest = sha256.convert(data);
    return digest.bytes;
  }
  
  /// Close the connection when done
  void dispose() {
    disconnect();
  }
}

/// HTTP-based fallback for ElectrumX (using HTTP bridge if available)
class ElectrumXHttpService {
  final String httpEndpoint;
  
  ElectrumXHttpService({this.httpEndpoint = AppConfig.electrumHttpEndpoint});
  
  /// Broadcast transaction via HTTP endpoint
  Future<String> broadcastTransaction(String rawTxHex) async {
    // This can be used if there's an HTTP bridge to ElectrumX
    // or if we use the explorer's /api/broadcast endpoint as fallback
    throw UnimplementedError('HTTP fallback not implemented');
  }
}
