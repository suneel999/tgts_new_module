import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

/// Mixin that provides access level filtering functionality
/// Can be used by screens that need to filter content by access level
mixin AccessLevelFilterMixin<T extends StatefulWidget> on State<T> {
  String _selectedAccessLevel = 'all';
  UserRole _userRole = UserRole.public;
  List<String> _availableAccessLevels = [];

  // Getters
  String get selectedAccessLevel => _selectedAccessLevel;
  UserRole get userRole => _userRole;
  List<String> get availableAccessLevels => _availableAccessLevels;

  /// Initialize filters - should be called in initState or similar
  void initializeFilters() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser != null) {
      _userRole = authService.currentUser!.role;
    }
    updateAvailableAccessLevels();
  }

  /// Update available access levels based on user role
  void updateAvailableAccessLevels() {
    if (_userRole == UserRole.admin) {
      _availableAccessLevels = ['all', 'public', 'cadre', 'admin'];
    } else if (_userRole == UserRole.cadre) {
      _availableAccessLevels = ['all', 'public', 'cadre'];
    } else {
      _availableAccessLevels = []; // Public users see no filters
    }
    
    // Reset selection if it's no longer valid
    if (_availableAccessLevels.isNotEmpty && !_availableAccessLevels.contains(_selectedAccessLevel)) {
      _selectedAccessLevel = 'all';
    }
  }

  /// Filter items by role permission
  /// Returns items that the current user role can see
  List<Item> filterByRole<Item>(List<Item> items, List<String> Function(Item) getAccessLevels) {
    if (_userRole == UserRole.admin) {
      // Admin sees everything
      return items;
    } else if (_userRole == UserRole.cadre) {
      // Cadre sees public and cadre items
      return items.where((item) {
        return getAccessLevels(item).any((level) {
          final l = level.toLowerCase();
          return l == 'public' || l == 'cadre';
        });
      }).toList();
    } else {
      // Public sees only public items
      return items.where((item) {
        return getAccessLevels(item).any((level) => level.toLowerCase() == 'public');
      }).toList();
    }
  }

  /// Filter items by selected access level chip
  List<Item> filterBySelectedLevel<Item>(
    List<Item> items,
    List<String> Function(Item) getAccessLevels,
  ) {
    if (_selectedAccessLevel == 'all') {
      return items;
    } else {
      return items.where((item) => 
        getAccessLevels(item).map((l) => l.toLowerCase()).contains(_selectedAccessLevel.toLowerCase())
      ).toList();
    }
  }

  /// Apply both role and selected level filters
  List<Item> applyFilters<Item>(
    List<Item> items,
    List<String> Function(Item) getAccessLevels,
  ) {
    final roleFiltered = filterByRole(items, getAccessLevels);
    return filterBySelectedLevel(roleFiltered, getAccessLevels);
  }

  /// Set the selected access level and trigger a rebuild
  void setSelectedAccessLevel(String level) {
    setState(() {
      _selectedAccessLevel = level;
    });
  }
}

