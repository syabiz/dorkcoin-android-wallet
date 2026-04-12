import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _secureStorage = FlutterSecureStorage();

  static const _pinHashKey = 'auth_pin_hash';
  static const _pinSaltKey = 'auth_pin_salt';
  static const _biometricEnabledKey = 'auth_biometric_enabled';

  bool get _useFallbackStore =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> setPin(String pin) async {
    if (pin.length < 4) {
      throw Exception('PIN must have at least 4 digits.');
    }

    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);

    await _writeValue(_pinSaltKey, salt);
    await _writeValue(_pinHashKey, hash);
  }

  Future<bool> isPinConfigured() async {
    final hash = await _readValue(_pinHashKey);
    final salt = await _readValue(_pinSaltKey);
    return hash != null && salt != null;
  }

  Future<bool> verifyPin(String pin) async {
    final savedHash = await _readValue(_pinHashKey);
    final salt = await _readValue(_pinSaltKey);

    if (savedHash == null || salt == null) {
      return false;
    }

    return _hashPin(pin, salt) == savedHash;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _writeValue(_biometricEnabledKey, enabled ? '1' : '0');
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _readValue(_biometricEnabledKey);
    return v == '1';
  }

  Future<bool> canUseBiometrics() async {
    final auth = LocalAuthentication();
    try {
      final available = await auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to unlock your wallet.',
  }) async {
    final auth = LocalAuthentication();
    try {
      return await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> requireSensitiveActionAuth() async {
    final biometricEnabled = await isBiometricEnabled();
    final canBio = await canUseBiometrics();

    if (biometricEnabled && canBio) {
      final ok = await authenticateWithBiometrics(
        reason: 'Authenticate to continue.',
      );
      if (ok) return true;
    }

    return false;
  }

  Future<void> clearAuth() async {
    await _deleteValue(_pinHashKey);
    await _deleteValue(_pinSaltKey);
    await _deleteValue(_biometricEnabledKey);
  }

  String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin::$salt');
    return sha256.convert(bytes).toString();
  }

  Future<void> _writeValue(String key, String value) async {
    if (_useFallbackStore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> _readValue(String key) async {
    if (_useFallbackStore) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _secureStorage.read(key: key);
  }

  Future<void> _deleteValue(String key) async {
    if (_useFallbackStore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }
}