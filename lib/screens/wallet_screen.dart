// =========================
// lib/screens/wallet_screen.dart
// =========================
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../models/wallet_info.dart';
import '../services/api_service.dart';
import '../services/secure_wallet_store.dart';
import 'history_screen.dart';
import 'send_screen.dart';

class WalletScreen extends StatefulWidget {
  final WalletInfo wallet;

  const WalletScreen({super.key, required this.wallet});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _api = ApiService();
  final _store = SecureWalletStore();

  bool _loading = true;
  String? _error;
  double _balance = 0.0;
  double? _DORKUsdPrice;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<double> _fetchDORKUsdPrice() async {
    // Try Explorer API first (more reliable)
    try {
      final response = await http.get(
        Uri.parse('https://explorer.dorkcoin.org/api/v1/lastprice'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final price = double.tryParse(response.body.trim());
        if (price != null && price > 0) {
          return price;
        }
      }
    } catch (e) {
      debugPrint('Explorer price fetch error: $e');
    }
    
    // Fallback to Cexius API
    try {
      final response = await http.get(
        Uri.parse('https://cexius.com/api/v2/markets/DORK-USDT/tickers'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ticker = data['ticker'];
        if (ticker != null && ticker is Map) {
          final lastPrice = ticker['last']?.toString();
          if (lastPrice != null && lastPrice.isNotEmpty) {
            return double.parse(lastPrice);
          }
        }
      }
    } catch (e) {
      debugPrint('Cexius price fetch error: $e');
    }
    
    throw Exception('Failed to fetch DORK price');
  }

  String _formatUsdtApprox(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(2);
    }
    if (value >= 1) {
      return value.toStringAsFixed(3);
    }
    if (value >= 0.01) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _priceError = null;
    });

    try {
      final balance = await _api.getBalance(widget.wallet.address);
      if (!mounted) return;
      setState(() {
        _balance = balance;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }

    try {
      final DORKUsdPrice = await _fetchDORKUsdPrice();
      if (!mounted) return;
      setState(() {
        _DORKUsdPrice = DORKUsdPrice;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _DORKUsdPrice = null;
        _priceError = 'Price data is currently unavailable.';
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: widget.wallet.address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard.')),
    );
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  Future<void> _showExportKeysDialog() async {
    var showSensitive = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildSecretField({
              required String label,
              required String value,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyText(label, value),
                        tooltip: 'Copy $label',
                        icon: const Icon(Icons.copy, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: showSensitive
                        ? SelectableText(value)
                        : const Text('••••••••••••••••••••••••••••••••'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Export Keys'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Keep these values secret. Anyone with your WIF or private key can spend your coins.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show sensitive data'),
                      subtitle: const Text('Hidden by default for safety.'),
                      value: showSensitive,
                      onChanged: (value) {
                        setDialogState(() {
                          showSensitive = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    buildSecretField(label: 'WIF', value: widget.wallet.wif),
                    const SizedBox(height: 12),
                    buildSecretField(
                      label: 'Private key (hex)',
                      value: widget.wallet.privateKeyHex,
                    ),
                    const SizedBox(height: 12),
                    buildSecretField(
                      label: 'Compressed public key',
                      value: widget.wallet.publicKeyHex,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndDeleteWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Wallet?'),
          content: const Text(
            'This will remove the locally stored wallet from this device. Make sure you have backed up your WIF or private key before continuing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Wallet'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _store.clearWallet();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Restart app to return to home.')),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dorkcoin Wallet'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _confirmAndDeleteWallet,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          onPressed: _copyAddress,
                          tooltip: 'Copy address',
                          icon: const Icon(Icons.copy, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(widget.wallet.address),
                    const SizedBox(height: 16),
                    if (_loading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance: $_balance DORK',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_DORKUsdPrice != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '≈ ${_formatUsdtApprox(_balance * _DORKUsdPrice!)} USDT',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '1 DORK ≈ ${_formatUsdtApprox(_DORKUsdPrice!)} USDT',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (_priceError != null) ...[
                      const SizedBox(height: 8),
                      Text(_priceError!, style: const TextStyle(color: Colors.orange)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SendScreen(wallet: widget.wallet),
                            ),
                          );
                        },
                        child: const Text('Send'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Receive', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: widget.wallet.address,
                      backgroundColor: Colors.white,
                      size: 220,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copyAddress,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Address'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(address: widget.wallet.address),
                  ),
                );
              },
              child: const Text('View History'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _showExportKeysDialog,
              child: const Text('Export Keys'),
            ),
          ],
        ),
      ),
    );
  }
}
