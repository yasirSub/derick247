import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _error;

  // Referral links
  String? pointAReferer;
  String? pointAVendor;

  // Totals
  int totalPointAReferer = 0;
  int totalPointAVendor = 0;
  int totalReferProduct = 0;

  // Commissions
  num convertedCommission = 0;
  num pendingCommission = 0;
  num possibleCommission = 0;

  // Products
  int pointWebProduct = 0;
  int vendorProduct = 0;
  int pointRegularProduct = 0;

  // Loan summary
  bool canGetLoan = false;
  num totalPossibleLoan = 0;
  num totalInterest = 0;
  num loanTaken = 0;

  // Loan requirements
  Map<String, String> loanRequirement = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    // Skip call if not authenticated
    if (AuthService().authToken == null) {
      _error = 'Unauthenticated';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final Response res = await _api.getDashboard();
      final data = res.data is Map<String, dynamic>
          ? res.data
          : (res.data as Map); // tolerate dynamic

      final status = data['status'];
      final payload = data['data'] ?? {};

      if (status == 'success' && payload is Map) {
        pointAReferer = payload['point_a_referer'];
        pointAVendor = payload['point_a_vendor'];

        final board = payload['board'] ?? {};
        final totals = board['totalReferrals'] ?? {};
        totalPointAReferer = (totals['point_a_referer'] ?? 0) as int;
        totalPointAVendor = (totals['point_a_vendor'] ?? 0) as int;
        totalReferProduct = (totals['referProduct'] ?? 0) as int;

        final comm = board['commissions'] ?? {};
        convertedCommission = (comm['converted_commission'] ?? 0) as num;
        pendingCommission = (comm['pending_commission'] ?? 0) as num;
        possibleCommission = (comm['possible_commission'] ?? 0) as num;

        final prods = board['products'] ?? {};
        pointWebProduct = (prods['point_web_product'] ?? 0) as int;
        vendorProduct = (prods['vendor_product'] ?? 0) as int;
        pointRegularProduct = (prods['point_regular_product'] ?? 0) as int;

        final loan = board['loan_summary'] ?? {};
        canGetLoan = (loan['can_get_loan'] ?? false) as bool;
        totalPossibleLoan = (loan['total_possible_loan'] ?? 0) as num;
        totalInterest = (loan['total_interest'] ?? 0) as num;
        loanTaken = (loan['loan_taken'] ?? 0) as num;

        final req = payload['loan_requirement'] ?? {};
        loanRequirement = {}
          ..addAll((req as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
      } else {
        _error = 'Failed to load dashboard';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}


