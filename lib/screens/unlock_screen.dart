import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _pinController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryBiometricUnlock();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometricUnlock() async {
    final enabled = await _authService.isBiometricEnabled();
    final canBio = await _authService.canUseBiometrics();
    if (!enabled || !canBio) return;

    final ok = await _authService.authenticateWithBiometrics(
      reason: 'Authenticate to unlock your wallet.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _unlockWithPin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await _authService.verifyPin(_pinController.text.trim());

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _loading = false;
      _error = 'Invalid PIN.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Enter your PIN to unlock the wallet.'),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _unlockWithPin(),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _unlockWithPin,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}