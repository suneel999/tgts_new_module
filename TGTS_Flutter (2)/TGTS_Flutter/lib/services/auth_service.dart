import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  Language _currentLanguage = Language.en;
  bool _isAuthenticated = false;
  String? _accessToken;
  bool? _hasMembership; // Cached membership status
  
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyUser = 'auth_user';
  static const String _keyIsAuthenticated = 'auth_is_authenticated';

  User? get currentUser => _currentUser;
  Language get currentLanguage => _currentLanguage;
  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  bool? get hasMembership => _hasMembership;

  void setLanguage(Language language) {
    _currentLanguage = language;
    notifyListeners();
  }

  // Initialize and load saved authentication state
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load access token
      _accessToken = prefs.getString(_keyAccessToken);
      
      // Load authentication status
      _isAuthenticated = prefs.getBool(_keyIsAuthenticated) ?? false;
      
      // Load user data
      final userJsonString = prefs.getString(_keyUser);
      if (userJsonString != null) {
        try {
          final userJson = jsonDecode(userJsonString) as Map<String, dynamic>;
          _currentUser = User.fromJson(userJson);
        } catch (e) {
          // If user data is corrupted, clear it
          await _clearSavedAuth();
          _currentUser = null;
          _isAuthenticated = false;
          _accessToken = null;
        }
      }
      
      // If we have a token but no user, clear everything
      if (_accessToken != null && _currentUser == null) {
        await _clearSavedAuth();
        _isAuthenticated = false;
        _accessToken = null;
      }
      
      notifyListeners();
    } catch (e) {
      // If there's any error loading, start fresh
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
    }
  }

  // Save authentication state to local storage
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_accessToken != null) {
        await prefs.setString(_keyAccessToken, _accessToken!);
      }
      
      await prefs.setBool(_keyIsAuthenticated, _isAuthenticated);
      
      if (_currentUser != null) {
        final userJson = jsonEncode(_currentUser!.toJson());
        await prefs.setString(_keyUser, userJson);
      }
    } catch (e) {
      // Handle error silently or log it
      print('Error saving auth state: $e');
    }
  }

  // Clear saved authentication state
  Future<void> _clearSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyUser);
      await prefs.remove(_keyIsAuthenticated);
    } catch (e) {
      // Handle error silently or log it
      print('Error clearing auth state: $e');
    }
  }

  Future<Map<String, dynamic>> sendOTP(String phone) async {
    final apiService = ApiService();
    final result = await apiService.sendOTP(phone);
    
    if (result['success']) {
      final data = result['data'];
      return {
        'success': true,
        'message': data['message'],
        'otp': data['otp'], // For debugging - remove in production
      };
    } else {
      return {
        'success': false,
        'message': result['message'] ?? 'Failed to send OTP',
      };
    }
  }

  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    final apiService = ApiService();
    final result = await apiService.verifyOTP(phone, otp);
    
    if (result['success']) {
      final data = result['data'];
      
      // Store the access token
      _accessToken = data['access_token'];
      
      // Create user object from response
      final userData = data['user'];
      print('🔍 verifyOTP - Raw userData keys: ${userData.keys.toList()}');
      print('🔍 verifyOTP - userData fullName: ${userData['fullName']}');
      print('🔍 verifyOTP - userData status: ${userData['status']}');
      print('🔍 verifyOTP - userData name: ${userData['name']}');
      
      _currentUser = User.fromJson(userData);
      
      // Check membership status from user data
      // fullName is from Member model, name is default User name
      final fullName = userData['fullName'];
      final status = userData['status'];
      _hasMembership = fullName != null && 
                      fullName.toString().trim().isNotEmpty &&
                      status != null &&
                      status.toString().trim().isNotEmpty;
      
      print('🔍 verifyOTP - fullName: $fullName, status: $status, hasMembership: $_hasMembership');
      print('🔍 verifyOTP - Current user fullName: ${_currentUser?.fullName}');
      print('🔍 verifyOTP - Current user status: ${_currentUser?.status}');
      
      _isAuthenticated = true;
      
      // Save authentication state to local storage
      await _saveAuthState();
      
      notifyListeners();
      
      return {
        'success': true,
        'message': data['message'],
        'user': _currentUser,
      };
    } else {
      return {
        'success': false,
        'message': result['message'] ?? 'Invalid OTP',
      };
    }
  }

  Future<bool> login(String phone, String otp) async {
    final result = await verifyOTP(phone, otp);
    return result['success'] ?? false;
  }

  Future<void> refreshProfile() async {
    if (_accessToken == null) return;

    final apiService = ApiService();
    final result = await apiService.getProfile(_accessToken!);

    if (result['success']) {
      final userData = result['data'];
      _currentUser = User.fromJson(userData);
      
      // Update membership status when refreshing profile
      final fullName = userData['fullName'];
      final status = userData['status'];
      _hasMembership = fullName != null && 
                      fullName.toString().trim().isNotEmpty &&
                      status != null &&
                      status.toString().trim().isNotEmpty;
      
      await _saveAuthState();
      notifyListeners();
    } else {
      // If the user is not found (404) or unauthorized (401), logout to fix state
      if (result['statusCode'] == 404 || result['statusCode'] == 401) {
        await logout();
      }
    }
  }

  /// Check if the current user has a membership
  /// Returns true if user has membership (Member record exists), false otherwise
  Future<bool> checkMembershipStatus() async {
    if (_accessToken == null) {
      _hasMembership = false;
      print('checkMembershipStatus - No access token, returning false');
      return false;
    }

    try {
      final apiService = ApiService();
      final result = await apiService.getProfile(_accessToken!);

      if (result['success']) {
        final userData = result['data'];
        
        // Check if member data exists - presence of fullName (not just name) and status indicates membership
        // The profile endpoint merges member data if it exists
        // User.name is the default "User_1234" name, fullName is from Member model
        final fullName = userData['fullName'];
        final status = userData['status'];
        
        // User has membership if fullName exists (and is not empty) AND status exists
        // fullName is only set when Member record exists
        final hasMembership = fullName != null && 
                             fullName.toString().trim().isNotEmpty &&
                             status != null &&
                             status.toString().trim().isNotEmpty;
        
        // Cache the membership status
        _hasMembership = hasMembership;
        
        // Update current user with latest data
        _currentUser = User.fromJson(userData);
        await _saveAuthState();
        notifyListeners();
        
        print('checkMembershipStatus - fullName=$fullName, status=$status, hasMembership=$hasMembership');
        
        return hasMembership;
      } else {
        // If the user is not found (404) or unauthorized (401), logout to fix state
        if (result['statusCode'] == 404 || result['statusCode'] == 401) {
          await logout();
        }
        _hasMembership = false;
        print('checkMembershipStatus - API call failed, returning false');
        return false;
      }
    } catch (e) {
      print('Error checking membership status: $e');
      _hasMembership = false;
      return false;
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    if (_accessToken == null) {
      return {
        'success': false,
        'message': 'Not authenticated',
      };
    }

    final apiService = ApiService();
    final result = await apiService.updateProfile(_accessToken!, profileData);

    if (result['success']) {
      final userData = result['data'];
      _currentUser = User.fromJson(userData);
      await _saveAuthState();
      notifyListeners();
      return {
        'success': true,
        'message': result['message'] ?? 'Profile updated successfully',
      };
    } else {
      return {
        'success': false,
        'message': result['message'] ?? 'Failed to update profile',
      };
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _isAuthenticated = false;
    _accessToken = null;
    _hasMembership = null;
    
    // Clear saved authentication state
    await _clearSavedAuth();
    
    notifyListeners();
  }

  // Get headers with authorization token
  Map<String, String> getAuthHeaders() {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }
}
