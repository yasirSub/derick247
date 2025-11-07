import 'package:flutter/material.dart';
import '../models/black_board_entry.dart';
import '../services/api_service.dart';

class BlackBoardProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<BlackBoardEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;

  List<BlackBoardEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get canLoadMore => _currentPage < _lastPage;

  Future<void> loadEntries({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _lastPage = 1;
      _entries = [];
      _error = null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getBlackBoard(page: _currentPage);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as List<dynamic>? ?? [];
        final pagination = response.data['pagination'] as Map<String, dynamic>?;

        final newEntries = data
            .map((item) {
              try {
                return BlackBoardEntry.fromJson(item);
              } catch (_) {
                return null;
              }
            })
            .whereType<BlackBoardEntry>()
            .toList();

        if (_currentPage == 1) {
          _entries = newEntries;
        } else {
          _entries = [..._entries, ...newEntries];
        }

        if (pagination != null) {
          _currentPage = (pagination['current_page'] ?? _currentPage).toInt();
          _lastPage = (pagination['last_page'] ?? _lastPage).toInt();
        }

        _error = null;
      } else {
        _error = response.data['message']?.toString() ?? 'Failed to load board';
      }
    } catch (e) {
      _error = 'Failed to load board: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!canLoadMore || _isLoading) return;
    _currentPage += 1;
    await loadEntries();
  }
}
