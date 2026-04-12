import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_info.dart';

class SecureWalletStore {
  static const _secureStorage = FlutterSecureStorage();

  static const _addressKey = 'wallet_address';
  static const _wifKey = 'wallet_wif';
  static const _privHexKey = 'wallet_priv_hex';
  static const _pubHexKey = 'wallet_pub_hex';

  bool get _useFallbackStore =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> saveWallet(WalletInfo wallet) async {
    if (_useFallbackStore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addressKey, wallet.address);
      await prefs.setString(_wifKey, wallet.wif);
      await prefs.setString(_privHexKey, wallet.privateKeyHex);
      await prefs.setString(_pubHexKey, wallet.publicKeyHex);
      return;
    }

    await _secureStorage.write(key: _addressKey, value: wallet.address);
    await _secureStorage.write(key: _wifKey, value: wallet.wif);
    await _secureStorage.write(key: _privHexKey, value: wallet.privateKeyHex);
    await _secureStorage.write(key: _pubHexKey, value: wallet.publicKeyHex);
  }

  Future<WalletInfo?> loadWallet() async {
    if (_useFallbackStore) {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_addressKey);
      final wif = prefs.getString(_wifKey);
      final privHex = prefs.getString(_privHexKey);
      final pubHex = prefs.getString(_pubHexKey);

      if (address == null || wif == null || privHex == null || pubHex == null) {
        return null;
      }

      return WalletInfo(
        address: address,
        wif: wif,
        privateKeyHex: privHex,
        publicKeyHex: pubHex,
      );
    }

    final address = await _secureStorage.read(key: _addressKey);
    final wif = await _secureStorage.read(key: _wifKey);
    final privHex = await _secureStorage.read(key: _privHexKey);
    final pubHex = await _secureStorage.read(key: _pubHexKey);

    if (address == null || wif == null || privHex == null || pubHex == null) {
      return null;
    }

    return WalletInfo(
      address: address,
      wif: wif,
      privateKeyHex: privHex,
      publicKeyHex: pubHex,
    );
  }

  Future<void> clearWallet() async {
    if (_useFallbackStore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_addressKey);
      await prefs.remove(_wifKey);
      await prefs.remove(_privHexKey);
      await prefs.remove(_pubHexKey);
      return;
    }

    await _secureStorage.delete(key: _addressKey);
    await _secureStorage.delete(key: _wifKey);
    await _secureStorage.delete(key: _privHexKey);
    await _secureStorage.delete(key: _pubHexKey);
  }
}