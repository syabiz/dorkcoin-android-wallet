import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _saving = false;
  bool _useBiometrics = false;
  String? _error;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBioAvailability();
  }

  Future<void> _loadBioAvailability() async {
    final available = await _authService.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final pin = _pinController.text.trim();
      final confirm = _confirmController.text.trim();

      if (pin.length < 4) {
        throw Exception('PIN must have at least 4 digits.');
      }
      if (pin != confirm) {
        throw Exception('PINs do not match.');
      }

      await _authService.setPin(pin);
      await _authService.setBiometricEnabled(_useBiometrics);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Protect your wallet with a PIN. You can also enable biometric unlock if the device supports it.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_bioAvailable)
              SwitchListTile(
                title: const Text('Enable biometric unlock'),
                subtitle: const Text('Fingerprint / Face ID / device auth'),
                value: _useBiometrics,
                onChanged: (v) {
                  setState(() {
                    _useBiometrics = v;
                  });
                },
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }
}