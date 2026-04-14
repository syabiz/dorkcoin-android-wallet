// =========================
// lib/screens/home_screen.dart
// =========================
import 'package:flutter/material.dart';

import '../models/wallet_info.dart';
import '../services/secure_wallet_store.dart';
import '../services/version_service.dart';
import '../widgets/update_dialog.dart';
import 'create_wallet_screen.dart';
import 'import_wallet_screen.dart';
import 'wallet_screen.dart';
import '../services/auth_service.dart';
import 'setup_pin_screen.dart';
import 'unlock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = SecureWalletStore();
  final _authService = AuthService();
  final _versionService = VersionService();
  bool _unlocked = false;
  WalletInfo? _wallet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(seconds: 2));

    final shouldCheck = await _versionService.shouldCheckVersion();
    if (!shouldCheck) return;

    final versionInfo = await _versionService.checkForUpdate();
    if (versionInfo == null || !versionInfo.hasUpdate) return;

    // Check if user has skipped this version
    final isSkipped = await _versionService.isVersionSkipped(versionInfo.latestVersion);
    if (isSkipped) return;

    if (!mounted) return;

    await UpdateDialog.show(
      context: context,
      versionInfo: versionInfo,
      onDismiss: () {},
      onSkip: () => _versionService.skipVersion(versionInfo.latestVersion),
    );
  }

  Future<void> _loadWallet() async {
    final wallet = await _store.loadWallet();
    final pinConfigured = await _authService.isPinConfigured();

    WalletInfo? visibleWallet = wallet;

    if (wallet != null && pinConfigured && !_unlocked && mounted) {
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const UnlockScreen()),
      );
      _unlocked = unlocked == true;
      if (!_unlocked) {
        visibleWallet = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _wallet = visibleWallet;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_wallet != null) {
      return WalletScreen(wallet: _wallet!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dorkcoin Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // Hero image at center top
            Center(
              child: Image.asset(
                'android/app/src/main/res/drawable/hero.png',
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create a new wallet or import an existing one. Private keys stay on this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateWalletScreen()),
                );
                final hasWallet = await _store.loadWallet();
                final pinConfigured = await _authService.isPinConfigured();
                if (hasWallet != null && !pinConfigured && mounted) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupPinScreen()),
                  );
                }
                _unlocked = true;
                _loadWallet();
              },
              child: const Text('Create Wallet'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
                );
                final hasWallet = await _store.loadWallet();
                final pinConfigured = await _authService.isPinConfigured();
                if (hasWallet != null && !pinConfigured && mounted) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupPinScreen()),
                  );
                }
                _unlocked = true;
                _loadWallet();
              },
              child: const Text('Import Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
