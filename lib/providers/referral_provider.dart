import 'package:flutter/material.dart';
import '../services/referral_service.dart';

class ReferralProvider extends ChangeNotifier {
  final ReferralService _referralService = ReferralService();

  double _totalEarnings = 0.0;
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;

  double get totalEarnings => _totalEarnings;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadReferralData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _totalEarnings = await _referralService.getTotalEarnings();
      _stats = await _referralService.getReferralStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> trackReferralClick(String referralCode) async {
    try {
      await _referralService.trackReferralClick(referralCode);
      // Refresh stats after tracking
      await loadReferralData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> trackReferralPurchase(
    String referralCode,
    double commission,
  ) async {
    try {
      await _referralService.trackReferralPurchase(referralCode, commission);
      // Refresh data after tracking
      await loadReferralData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  String generateReferralCode(int productId, String userId) {
    return _referralService.generateReferralCode(productId, userId);
  }

  Future<void> clearReferralData() async {
    try {
      await _referralService.clearReferralData();
      _totalEarnings = 0.0;
      _stats = {};
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Getters for specific stats
  int get totalClicks => _stats['totalClicks'] ?? 0;
  int get totalPurchases => _stats['totalPurchases'] ?? 0;
  double get totalCommission => _stats['totalCommission'] ?? 0.0;
  double get conversionRate => _stats['conversionRate'] ?? 0.0;
}
