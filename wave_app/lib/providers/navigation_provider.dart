import 'package:flutter/material.dart';

/// Navigation provider — manages global app navigation state.
/// Allows any screen to switch tabs or trigger a search.
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  String? _pendingSearchQuery;

  int get currentIndex => _currentIndex;
  String? get pendingSearchQuery => _pendingSearchQuery;

  void setTab(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Switches to the search tab and prepares a query.
  void triggerSearch(String query) {
    _pendingSearchQuery = query;
    _currentIndex = 1; // Search tab index
    notifyListeners();
  }

  /// Clears the pending query once it has been consumed by the SearchScreen.
  void consumeSearchQuery() {
    _pendingSearchQuery = null;
    // Don't notifyListeners here to avoid rebuild loops in SearchScreen's didChangeDependencies
  }
}
