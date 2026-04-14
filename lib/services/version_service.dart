// =========================
// lib/services/version_service.dart
// Version check service for GitHub releases
// =========================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VersionInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? releaseNotes;
  final bool hasUpdate;

  const VersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
    required this.hasUpdate,
  });
}

class VersionService {
  static const String _currentVersion = '1.0.2'; // Current app version
  static const String _githubApiUrl = 'https://api.github.com/repos/syabiz/dorkcoin-android-wallet/releases/latest';
  static const String _versionCheckKey = 'last_version_check';
  static const String _skippedVersionKey = 'skipped_version';
  static const Duration _checkInterval = Duration(hours: 24); // Check once per day

  String get currentVersion => _currentVersion;

  /// Check if version check should be performed (based on last check time)
  Future<bool> shouldCheckVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_versionCheckKey);
    if (lastCheck == null) return true;

    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    return DateTime.now().difference(lastCheckTime) >= _checkInterval;
  }

  /// Mark version check as completed
  Future<void> markVersionChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Skip a specific version
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, version);
  }

  /// Check if a version has been skipped
  Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_skippedVersionKey);
    return skipped == version;
  }

  /// Fetch latest version from GitHub releases
  Future<VersionInfo?> checkForUpdate() async {
    try {
      if (kDebugMode) print('Checking for updates from GitHub...');

      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (kDebugMode) print('Failed to check for updates: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      final htmlUrl = data['html_url'] as String?;
      final body = data['body'] as String?;

      if (tagName == null || htmlUrl == null) {
        if (kDebugMode) print('Invalid release data received');
        return null;
      }

      // Parse version from tag (e.g., "v1.0.3" -> "1.0.3")
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      // Compare versions
      final hasUpdate = _compareVersions(latestVersion, _currentVersion) > 0;

      if (kDebugMode) {
        print('Version check: current=$_currentVersion, latest=$latestVersion, hasUpdate=$hasUpdate');
      }

      await markVersionChecked();

      return VersionInfo(
        currentVersion: _currentVersion,
        latestVersion: latestVersion,
        releaseUrl: htmlUrl,
        releaseNotes: body,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      if (kDebugMode) print('Error checking for updates: $e');
      return null;
    }
  }

  /// Compare two version strings (e.g., "1.0.3" vs "1.0.2")
  /// Returns: positive if v1 > v2, negative if v1 < v2, 0 if equal
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).whereType<int>().toList();
    final parts2 = v2.split('.').map(int.tryParse).whereType<int>().toList();

    for (int i = 0; i < parts1.length && i < parts2.length; i++) {
      final cmp = parts1[i].compareTo(parts2[i]);
      if (cmp != 0) return cmp;
    }

    return parts1.length.compareTo(parts2.length);
  }
}
