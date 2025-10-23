import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final String _referralEarningsKey = 'referral_earnings';
  final String _referralHistoryKey = 'referral_history';

  // Generate a unique referral code for a product
  String generateReferralCode(int productId, String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'REF${productId}_${userId}_$timestamp';
  }

  // Generate referral link
  String generateReferralLink(Product product, String referralCode) {
    return '${product.shareLink}?ref=$referralCode';
  }

  // Track referral click
  Future<void> trackReferralClick(String referralCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_referralHistoryKey) ?? [];

      final clickData = {
        'referralCode': referralCode,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'click',
      };

      history.add(clickData.toString());
      await prefs.setStringList(_referralHistoryKey, history);
    } catch (e) {
      print('Error tracking referral click: $e');
    }
  }

  // Track referral purchase
  Future<void> trackReferralPurchase(
    String referralCode,
    double commission,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Add to earnings
      final currentEarnings = prefs.getDouble(_referralEarningsKey) ?? 0.0;
      await prefs.setDouble(_referralEarningsKey, currentEarnings + commission);

      // Add to history
      final history = prefs.getStringList(_referralHistoryKey) ?? [];
      final purchaseData = {
        'referralCode': referralCode,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'purchase',
        'commission': commission,
      };

      history.add(purchaseData.toString());
      await prefs.setStringList(_referralHistoryKey, history);
    } catch (e) {
      print('Error tracking referral purchase: $e');
    }
  }

  // Get total referral earnings
  Future<double> getTotalEarnings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_referralEarningsKey) ?? 0.0;
    } catch (e) {
      print('Error getting total earnings: $e');
      return 0.0;
    }
  }

  // Get referral history
  Future<List<Map<String, dynamic>>> getReferralHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_referralHistoryKey) ?? [];

      return history.map((item) {
        // Parse the stored data (simplified parsing)
        return {'data': item, 'timestamp': DateTime.now().toIso8601String()};
      }).toList();
    } catch (e) {
      print('Error getting referral history: $e');
      return [];
    }
  }

  // Clear referral data
  Future<void> clearReferralData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_referralEarningsKey);
      await prefs.remove(_referralHistoryKey);
    } catch (e) {
      print('Error clearing referral data: $e');
    }
  }

  // Get referral statistics
  Future<Map<String, dynamic>> getReferralStats() async {
    try {
      final history = await getReferralHistory();
      final totalEarnings = await getTotalEarnings();

      int clicks = 0;
      int purchases = 0;
      double totalCommission = 0.0;

      for (final item in history) {
        final data = item['data'].toString();
        if (data.contains('action: click')) {
          clicks++;
        } else if (data.contains('action: purchase')) {
          purchases++;
          // Extract commission from the data (simplified)
          if (data.contains('commission:')) {
            final commissionMatch = RegExp(
              r'commission: ([\d.]+)',
            ).firstMatch(data);
            if (commissionMatch != null) {
              totalCommission +=
                  double.tryParse(commissionMatch.group(1)!) ?? 0.0;
            }
          }
        }
      }

      return {
        'totalClicks': clicks,
        'totalPurchases': purchases,
        'totalEarnings': totalEarnings,
        'totalCommission': totalCommission,
        'conversionRate': clicks > 0 ? (purchases / clicks * 100) : 0.0,
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {
        'totalClicks': 0,
        'totalPurchases': 0,
        'totalEarnings': 0.0,
        'totalCommission': 0.0,
        'conversionRate': 0.0,
      };
    }
  }
}
