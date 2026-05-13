import 'dart:io';

/// Central API configuration for TGTS mobile app.
/// Production base URL must match the deployed Flask API (`/api` prefix is included).
class ApiConfig {
  /// **Release APK:** keep `true` so all devices use EC2 + Cloudflare (`api.tgtccon2025.com`).
  /// Set `false` only for local/dev (emulator uses [localAndroidEmulator]).
  static const bool useProduction = true;

  /// Live production API (Flask-RESTX mounted at `/api`).
  static const String productionUrl = 'https://api.tgtccon2025.com/api';

  /// Android emulator → host machine (use only when [useProduction] is false).
  static const String localAndroidEmulator = 'http://10.0.2.2:5000/api';

  static const String localIOSSimulator = 'http://127.0.0.1:5000/api';
  static const String localHost = 'http://localhost:5000/api';

  static String get baseUrl {
    if (useProduction) {
      return productionUrl;
    }
    if (Platform.isAndroid) {
      return localAndroidEmulator;
    }
    if (Platform.isIOS) {
      return localIOSSimulator;
    }
    return localHost;
  }

  /// Matches Flask route registered as `/api/health`.
  static String get healthUrl {
    if (useProduction) {
      return '$productionUrl/health';
    }
    if (Platform.isAndroid) {
      return '$localAndroidEmulator/health';
    }
    if (Platform.isIOS) {
      return '$localIOSSimulator/health';
    }
    return '$localHost/health';
  }

  /// Host used for `/uploads/...` — API base includes `/api`; static uploads do not.
  static String get publicOrigin {
    final u = baseUrl;
    if (u.endsWith('/api')) {
      return u.substring(0, u.length - 4);
    }
    return u;
  }

  static String resolveMediaUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$publicOrigin$trimmed';
    }
    return trimmed;
  }

  static String getFullUrl(String endpoint) {
    if (endpoint == '/health') {
      return healthUrl;
    }
    return '$baseUrl$endpoint';
  }

  static const String loginEndpoint = '/auth/login';
  static const String verifyOtpEndpoint = '/auth/verify-otp';
  static const String profileEndpoint = '/auth/profile';
  static const String logoutEndpoint = '/auth/logout';
  static const String voterListEndpoint = '/voter-list';
  static const String schemeBeneficiariesEndpoint = '/scheme-beneficiaries';

  static const int timeoutDuration = 30;

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
