// =========================
// lib/config.dart
// =========================
class AppConfig {
  // Explorer API base URL (for read-only operations)
  static const String apiBaseUrl = 'https://explorer.dorkcoin.org';
  
  // ElectrumX Server Configuration
  // Using ElectrumX for transaction broadcast and real-time blockchain data
  static const String electrumHost = 'electrumx.dorkcoin.org';
  static const int electrumPort = 50002;  // SSL port
  static const bool electrumUseSsl = true; // SSL required for port 50002
  
  // Fallback HTTP endpoint (if available)
  static const String electrumHttpEndpoint = 'https://electrumx.dorkcoin.org';
  
  // Network Configuration
  static const int requiredConfirmations = 6;
  static const int defaultFeePerKb = 10000; // satoshis per KB
}
