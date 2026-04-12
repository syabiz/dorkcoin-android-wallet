// =========================
// lib/screens/import_wallet_screen.dart
// =========================
import 'package:flutter/material.dart';

import '../services/secure_wallet_store.dart';
import '../services/wallet_service.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _hexController = TextEditingController();
  final _walletService = WalletService();
  final _store = SecureWalletStore();

  String? _error;

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    try {
      final wallet = _walletService.importWallet(_hexController.text);
      await _store.saveWallet(wallet);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Import from a 32-byte private key hex or a compressed WIF.'),
            const SizedBox(height: 12),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Private key hex or compressed WIF',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _import,
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }
}
