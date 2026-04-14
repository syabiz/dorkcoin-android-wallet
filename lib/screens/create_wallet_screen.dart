// =========================
// lib/screens/create_wallet_screen.dart
// =========================
import 'package:flutter/material.dart';

import '../models/wallet_info.dart';
import '../services/secure_wallet_store.dart';
import '../services/wallet_service.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final _walletService = WalletService();
  final _store = SecureWalletStore();

  WalletInfo? _wallet;

  @override
  void initState() {
    super.initState();
    _wallet = _walletService.generateWallet();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet!;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Write down your WIF and keep it safe. Anyone with the WIF can spend your coins.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _kv('Address', wallet.address),
            _kv('WIF', wallet.wif),
            _kv('Private key (hex)', wallet.privateKeyHex),
            _kv('Compressed public key', wallet.publicKeyHex),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _store.saveWallet(wallet);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Save Wallet'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _wallet = _walletService.generateWallet();
                });
              },
              child: const Text('Generate Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(value),
          ],
        ),
      ),
    );
  }
}
