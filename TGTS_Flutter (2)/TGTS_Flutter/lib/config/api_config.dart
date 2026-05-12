// import 'dart:io';
// import 'package:flutter/foundation.dart';

// class ApiConfig {
//   // Base URL for the Flask backend API
//   // Production server endpoint
  
//   // Set to true to use production API, false for local development
//   static const bool useProduction = true;
  
//   // Production API URL
//   static const String productionUrl = 'https://apitgts.codeology.solutions/api';
  
//   // Local development URLs
//   static const String localAndroidEmulator = 'http://10.0.2.2:5000/api';
//   static const String localIOSSimulator = 'http://127.0.0.1:5000/api';
//   static const String localHost = 'http://localhost:5000/api';
  
//   static String get baseUrl {
//     // Use production URL by default (works on all devices including physical phones)
//     if (useProduction) {
//       return productionUrl;
//     }
    
//     // Local development URLs (only work in emulators/simulators)
//     if (Platform.isAndroid) {
//       // Android emulator needs special IP to reach host machine
//       // Note: This only works in emulator, not on physical devices
//       return localAndroidEmulator;
//     } else if (Platform.isIOS) {
//       // iOS simulator can use localhost
//       return localIOSSimulator;
//     } else {
//       // Web and desktop can use localhost
//       return localHost;
//     }
//   }
  
//   // Health endpoint
//   static String get healthUrl {
//     if (useProduction) {
//       return '$productionUrl/health';
//     }
    
//     if (Platform.isAndroid) {
//       return '$localAndroidEmulator/health';
//     } else if (Platform.isIOS) {
//       return '$localIOSSimulator/health';
//     } else {
//       return '$localHost/health';
//     }
//   }
  
//   // Helper method to get full URL for any endpoint
//   static String getFullUrl(String endpoint) {
//     if (endpoint == '/health') {
//       return healthUrl;
//     }
//     return '$baseUrl$endpoint';
//   }
  
//   // Alternative URLs for different environments
//   // Uncomment and modify as needed:
  
//   // Production API endpoint for cross-device testing:
//   // static const String baseUrl = 'https://apitgts.codeology.solutions/api';
  
//   // For Android emulator (local development):
//   // static const String baseUrl = 'http://10.0.2.2:5001/api';
  
//   // For iOS simulator (local development):
//   // static const String baseUrl = 'http://127.0.0.1:5001/api';
  
//   // For local development (if running on web or desktop):
//   // static const String baseUrl = 'http://localhost:5001/api';
  
//   // For development with iOS simulator:
//   // static const String baseUrl = 'http://127.0.0.1:5001/api';
  
//   // For physical device (replace with your computer's IP):
//   // static const String baseUrl = 'http://192.168.0.218:5001/api';
  
//   // For production:
//   // static const String baseUrl = 'https://apitgts.codeology.solutions/api';
  
//   // API endpoints
//   static const String loginEndpoint = '/auth/login';
//   static const String verifyOtpEndpoint = '/auth/verify-otp';
//   static const String profileEndpoint = '/auth/profile';
//   static const String logoutEndpoint = '/auth/logout';
  
//   // Request timeout duration in seconds
//   static const int timeoutDuration = 30;
  
//   // Headers
//   static Map<String, String> get defaultHeaders => {
//     'Content-Type': 'application/json',
//     'Accept': 'application/json',
//   };
  
// }


import 'dart:io';

class ApiConfig {
  // Base URL for the Flask backend API
  // Production server endpoint
  
  // Set to true to use production API, false for local development
  static const bool useProduction = true;

  // Production API URL (https required for Play Store / real devices)
  static const String productionUrl = 'https://api.tgtccon2025.com/api';


  // Local development URLs
  //static const String localAndroidEmulator = 'http://10.0.2.2:5000/api';
  static const String localAndroidEmulator = 'http://127.0.0.1:5000/api';
  static const String localIOSSimulator = 'http://127.0.0.1:5000/api';
  static const String localHost = 'http://localhost:5000/api';

  static String get baseUrl {
    // Use production URL by default (works on all devices including physical phones)
    if (useProduction) {
      return productionUrl;
    }
    
    // Local development URLs (only work in emulators/simulators)
    if (Platform.isAndroid) {
      // Android emulator needs special IP to reach host machine
      // Note: This only works in emulator, not on physical devices
      return localAndroidEmulator;
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return localIOSSimulator;
    } else {
      // Web and desktop can use localhost
      return localHost;
    }
  }
  
  // Health endpoint
  static String get healthUrl {
    if (useProduction) {
      return '$productionUrl/health';
    }
    
    if (Platform.isAndroid) {
      return '$localAndroidEmulator/health';
    } else if (Platform.isIOS) {
      return '$localIOSSimulator/health';
    } else {
      return '$localHost/health';
    }
  }
  
  // Helper method to get full URL for any endpoint
  static String getFullUrl(String endpoint) {
    if (endpoint == '/health') {
      return healthUrl;
    }
    return '$baseUrl$endpoint';
  }

  // Alternative URLs for different environments
  // Uncomment and modify as needed:
  
  // Production API endpoint for cross-device testing:
  // static const String baseUrl = 'https://apitgts.codeology.solutions/api';
  
  // For Android emulator (local development):
  // static const String baseUrl = 'http://10.0.2.2:5001/api';
  
  // For iOS simulator (local development):
  // static const String baseUrl = 'http://127.0.0.1:5001/api';
  
  // For local development (if running on web or desktop):
  // static const String baseUrl = 'http://localhost:5001/api';
  
  // For development with iOS simulator:
  // static const String baseUrl = 'http://127.0.0.1:5001/api';
  
  // For physical device (replace with your computer's IP):
  // static const String baseUrl = 'http://192.168.0.218:5001/api';
  
  // For production:
  // static const String baseUrl = 'https://apitgts.codeology.solutions/api';
  
  // API endpoints
  static const String loginEndpoint = '/auth/login';
  static const String verifyOtpEndpoint = '/auth/verify-otp';
  static const String profileEndpoint = '/auth/profile';
  static const String logoutEndpoint = '/auth/logout';
  static const String voterListEndpoint         = '/voter-list';
  static const String schemeBeneficiariesEndpoint = '/scheme-beneficiaries';
  
  // Request timeout duration in seconds
  static const int timeoutDuration = 30;
  
  // Headers
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
}


