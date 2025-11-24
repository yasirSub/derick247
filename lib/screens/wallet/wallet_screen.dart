import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../config/theme_config.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/translated_text.dart';
import '../checkout/paypal_webview_screen.dart';
import '../auth/login_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _walletData;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = false;
  late TabController _tabController;
  late PageController _walletPageController;
  int _currentWalletIndex = 0;
  bool _isListView = false; // false = side view (stacked), true = list view
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _walletPageController = PageController();
    _loadWalletData();
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _walletPageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isListView && _walletPageController.hasClients) {
        try {
          if (_currentWalletIndex < 2) {
            _walletPageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } else {
            // Reset to first page
            _walletPageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        } catch (e) {
          // PageController not ready yet, cancel timer
          debugPrint('⚠️ [Wallet] PageController error: $e');
          _autoScrollTimer?.cancel();
          _autoScrollTimer = null;
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  String _formatBalance(dynamic balance) {
    if (balance == null) return '0';
    final balanceNum = balance is num
        ? balance
        : double.tryParse(balance.toString()) ?? 0;
    // Format with commas for thousands, no decimal places
    return balanceNum
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getWallet();

      if (response.statusCode == 200) {
        setState(() {
          _walletData = response.data['data'];
        });
      } else {
        // Check for 401 Unauthorized
        if (response.statusCode == 401) {
          // Redirect to login screen
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false, // Remove all previous routes
            );
          }
          return;
        }

        setState(() {
          _error =
              response.data['message']?.toString() ??
              TranslationService().translate(
                'wallet.failedToLoadWalletInformation',
              );
        });
      }
    } catch (e) {
      // Handle DioException with 401 status code
      if (e is DioException && e.response?.statusCode == 401) {
        // Redirect to login screen on 401 error
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false, // Remove all previous routes
          );
        }
        return;
      }

      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      debugPrint('📊 [Wallet] Loading transactions...');
      final response = await _apiService.getTransactions();

      debugPrint('📊 [Wallet] Transactions API Response:');
      debugPrint('   → Status Code: ${response.statusCode}');
      debugPrint('   → Success: ${response.data['success']}');
      debugPrint('   → Data: ${response.data['data']}');

      // Check for 401 Unauthorized
      if (response.statusCode == 401) {
        // Redirect to login screen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false, // Remove all previous routes
          );
        }
        return;
      }

      if (response.statusCode == 200 && response.data['success'] == true) {
        final transactionsData = response.data['data']['data'] as List?;

        debugPrint('   → Transactions Count: ${transactionsData?.length ?? 0}');

        if (transactionsData != null && transactionsData.isNotEmpty) {
          final mappedTransactions = transactionsData.map((transaction) {
            // Map API response to UI format
            final transactionFor =
                transaction['transaction_for']?.toString() ?? '';
            final isCredit =
                transactionFor.toLowerCase().contains('topup') ||
                transactionFor.toLowerCase().contains('commission');

            // Clean amount (remove commas for display)
            final amountStr = transaction['amount']?.toString() ?? '0.00';
            final cleanAmount = amountStr.replaceAll(',', '');

            debugPrint(
              '   → Mapping transaction: ${transaction['transaction_id']}',
            );
            debugPrint('      → Type: $transactionFor');
            debugPrint('      → Amount: $amountStr -> $cleanAmount');
            debugPrint('      → Is Credit: $isCredit');

            return {
              'id': transaction['transaction_id']?.toString() ?? '',
              'type': transactionFor,
              'amount': cleanAmount,
              'isCredit': isCredit,
              'status': transaction['status']?.toString() ?? '',
              'date': transaction['date']?.toString() ?? '',
            };
          }).toList();

          debugPrint(
            '📊 [Wallet] Mapped ${mappedTransactions.length} transactions',
          );
          setState(() {
            _transactions = mappedTransactions;
          });
        } else {
          debugPrint('⚠️ [Wallet] No transactions data or empty list');
          setState(() {
            _transactions = [];
          });
        }
      } else {
        debugPrint('❌ [Wallet] API response not successful');
        debugPrint('   → Response: ${response.data}');
        setState(() {
          _transactions = [];
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [Wallet] Error loading transactions: $e');
      debugPrint('   → Stack trace: $stackTrace');

      // Handle DioException with 401 status code
      if (e is DioException && e.response?.statusCode == 401) {
        // Redirect to login screen on 401 error
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false, // Remove all previous routes
          );
        }
        return;
      }

      setState(() {
        _transactions = [];
      });
    } finally {
      setState(() {
        _isLoadingTransactions = false;
      });
      debugPrint(
        '📊 [Wallet] Finished loading transactions. Count: ${_transactions.length}',
      );
    }
  }

  Future<void> _handleBuyPoints() async {
    final pointsController = TextEditingController();
    String? selectedPaymentSource; // 'paypal' or 'wallet'
    bool _isSubmitting = false;

    // Capture the parent context before showing dialog
    final parentContext = context;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B), // Dark blue-grey
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Points Icon from slider
                          Image.asset(
                            'assets/mobile/points icon.png',
                            width: 28,
                            height: 28,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.diamond,
                                  color: Colors.white,
                                  size: 28,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            TranslationService().translate('wallet.buyEquxx'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Points field
                Text(
                  TranslationService().translate('wallet.points'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF334155), // Dark grey
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintText: TranslationService().translate(
                      'wallet.enterPointsMin',
                    ),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment source selection buttons (horizontal)
                Row(
                  children: [
                    // PayPal button (payment source)
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedPaymentSource = 'paypal';
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A), // Dark blue
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedPaymentSource == 'paypal'
                                  ? const Color(
                                      0xFFFFC439,
                                    ) // Gold border when selected
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // PayPal Icon
                              SizedBox(
                                width: 28,
                                height: 20,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF003087),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 8,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF009CDE),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                TranslationService()
                                        .translate('checkout.paymentMethod')
                                        .contains('PayPal')
                                    ? 'PayPal'
                                    : 'PayPal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Wallet button (payment source)
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedPaymentSource = 'wallet';
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A), // Dark blue
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedPaymentSource == 'wallet'
                                  ? const Color(
                                      0xFFFFC439,
                                    ) // Gold border when selected
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Wallet Icon
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                TranslationService().translate('wallet.wallet'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // PayPal action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || selectedPaymentSource == null)
                        ? null
                        : () async {
                            if (pointsController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: TranslatedText(
                                    'wallet.pleaseEnterPoints',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            final points = int.tryParse(
                              pointsController.text.trim(),
                            );
                            if (points == null || points < 5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: TranslatedText(
                                    'wallet.minimumPointsRequired',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              _isSubmitting = true;
                            });

                            try {
                              // Use different endpoint based on payment source
                              final response = selectedPaymentSource == 'wallet'
                                  ? await _apiService.buyPointsWithWallet({
                                      'points': pointsController.text.trim(),
                                      'payment_source': selectedPaymentSource,
                                      'payment_method':
                                          selectedPaymentSource, // Some APIs use payment_method
                                    })
                                  : await _apiService.buyPoints({
                                      'points': pointsController.text.trim(),
                                      'payment_source': selectedPaymentSource,
                                      'payment_method':
                                          selectedPaymentSource, // Some APIs use payment_method
                                    });

                              debugPrint(
                                '💳 Wallet order response -> status: ${response.statusCode}, payment_source: $selectedPaymentSource',
                              );
                              debugPrint(
                                '💳 Wallet order response data: ${response.data}',
                              );

                              if (mounted) {
                                if (response.statusCode == 200 ||
                                    response.statusCode == 201) {
                                  final responseData = response.data;

                                  // Check if response status is success
                                  if (responseData != null &&
                                      responseData is Map &&
                                      responseData['status'] == 'success') {
                                    // Handle PayPal redirect if approval link exists
                                    // Check BEFORE popping dialog to ensure context is valid
                                    if (selectedPaymentSource == 'paypal') {
                                      // Try multiple locations for approval link
                                      dynamic rawApprovalLink;
                                      if (responseData['approvalLink'] != null) {
                                        rawApprovalLink =
                                            responseData['approvalLink'];
                                      } else if (responseData['approval_url'] !=
                                          null) {
                                        rawApprovalLink =
                                            responseData['approval_url'];
                                      } else if (responseData['approvalUrl'] !=
                                          null) {
                                        rawApprovalLink =
                                            responseData['approvalUrl'];
                                      } else if (responseData['data'] is Map) {
                                        final data = responseData['data'] as Map;
                                        rawApprovalLink =
                                            data['approvalLink'] ??
                                            data['approval_url'] ??
                                            data['approvalUrl'];
                                      }

                                      debugPrint(
                                        '💳 PayPal approval link: $rawApprovalLink',
                                      );

                                      if (rawApprovalLink != null &&
                                          rawApprovalLink.toString().isNotEmpty) {
                                        final approvalLink = rawApprovalLink
                                            .toString();

                                        // Pop dialog first
                                        Navigator.of(dialogContext).pop();

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            parentContext,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Opening PayPal...'),
                                              backgroundColor:
                                                  AppTheme.successColor,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );

                                          final paypalResult =
                                              await Navigator.of(parentContext).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PaypalWebViewScreen(
                                                        approvalUrl: approvalLink,
                                                      ),
                                                ),
                                              );

                                          // Handle PayPal return result
                                          if (mounted && paypalResult != null) {
                                            if (paypalResult is Map) {
                                              final isSuccess =
                                                  paypalResult['success'] == true;

                                              if (isSuccess) {
                                                // Payment successful - reload wallet and show success message
                                                await Future.delayed(const Duration(seconds: 1));
                                                await _loadWalletData();
                                                await _loadTransactions();

                                                ScaffoldMessenger.of(
                                                  parentContext,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '${responseData['points'] != null ? '${responseData['points']} points ' : ''}added successfully! Your wallet balance has been updated.',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.successColor,
                                                    duration: const Duration(
                                                      seconds: 4,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                // Payment cancelled or failed
                                                ScaffoldMessenger.of(
                                                  parentContext,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Payment was cancelled',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.errorColor,
                                                  ),
                                                );
                                              }
                                            } else {
                                              // Fallback: reload wallet anyway
                                              await Future.delayed(const Duration(seconds: 1));
                                              await _loadWalletData();
                                              await _loadTransactions();
                                              ScaffoldMessenger.of(
                                                parentContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${responseData['points'] != null ? '${responseData['points']} points ' : ''}added successfully! Your wallet balance has been updated.',
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.successColor,
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                        return;
                                      } else {
                                        debugPrint(
                                          '⚠️ PayPal selected but no approval link found in response',
                                        );
                                      }
                                    } else {
                                      // Handle wallet payment (non-PayPal)
                                      // Pop dialog first
                                      Navigator.of(dialogContext).pop();
                                      
                                      ScaffoldMessenger.of(parentContext).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${responseData['points'] != null ? '${responseData['points']} points ' : ''}added successfully! Your wallet balance has been updated.',
                                          ),
                                          backgroundColor: AppTheme.successColor,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                      
                                      // Reload wallet data
                                      await _loadWalletData();
                                      await _loadTransactions();
                                    }
                                  } else {
                                    // Status is not 'success'
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          responseData['message']?.toString() ??
                                              'Failed to process payment',
                                        ),
                                        backgroundColor: AppTheme.errorColor,
                                      ),
                                    );
                                  }
                                } else {
                                  Navigator.of(dialogContext).pop();
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response.data['message']?.toString() ??
                                            TranslationService().translate(
                                              'wallet.failedToPurchasePoints',
                                            ),
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedPaymentSource == null
                          ? Colors.grey
                          : const Color(0xFFFFC439), // Gold
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF003087),
                              ),
                            ),
                          )
                        : Text(
                            selectedPaymentSource == 'paypal'
                                ? 'Pay by PayPal'
                                : selectedPaymentSource == 'wallet'
                                    ? 'Pay by Wallet'
                                    : 'Buy Now',
                            style: const TextStyle(
                              color: Color(0xFF003087), // PayPal blue
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 16),

                // Powered by PayPal
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TranslationService().translate('wallet.poweredBy'),
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'PayPal',
                        style: TextStyle(
                          color: Color(0xFF003087),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final emailController = TextEditingController();
    final amountController = TextEditingController();
    bool _isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B), // Dark blue-grey
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Send Money from Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                const SizedBox(height: 8),

                // Email field
                Text(
                  TranslationService().translate('app.email'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF334155), // Dark grey
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintText: TranslationService().translate(
                      'wallet.enterRecipientEmail',
                    ),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Amount field
                const Text(
                  'Amount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF334155), // Dark grey
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Enter amount',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixText: '\$',
                    prefixStyle: const TextStyle(color: Colors.white),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (emailController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: TranslatedText(
                                    'wallet.pleaseEnterRecipientEmail',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            if (amountController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter amount'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              _isSubmitting = true;
                            });

                            try {
                              final email = emailController.text.trim();
                              final amount = amountController.text.trim();
                              
                              debugPrint('💸 [WALLET SCREEN] Sending money:');
                              debugPrint('   → Email: $email');
                              debugPrint('   → Amount: $amount');
                              
                              final response = await _apiService.sendMoney({
                                'email': email,
                                'amount': amount,
                              });

                              debugPrint('💸 [WALLET SCREEN] Send money response:');
                              debugPrint('   → Status Code: ${response.statusCode}');
                              debugPrint('   → Response: ${response.data}');

                              if (mounted) {
                                Navigator.of(context).pop();

                                // Check if response is successful (status code 200 or status field is success)
                                final responseData = response.data;
                                final isSuccess = response.statusCode == 200 ||
                                    (responseData != null &&
                                        responseData is Map &&
                                        (responseData['status'] == 'success' ||
                                            responseData['success'] == true));

                                if (isSuccess) {
                                  // Reload wallet data
                                  await _loadWalletData();

                                  // Show success snackbar message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        responseData != null &&
                                                responseData is Map
                                            ? (responseData['message']
                                                    ?.toString() ??
                                                'Money sent successfully!')
                                            : 'Money sent successfully!',
                                      ),
                                      backgroundColor: AppTheme.successColor,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  // Show error snackbar message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        responseData != null &&
                                                responseData is Map
                                            ? (responseData['message']
                                                    ?.toString() ??
                                                TranslationService().translate(
                                                  'wallet.failedToSendMoney',
                                                ))
                                            : TranslationService().translate(
                                                'wallet.failedToSendMoney',
                                              ),
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED), // Purple
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Send',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleWithdraw() async {
    final emailController = TextEditingController();
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final amountController = TextEditingController();
    String? selectedPaymentMethod; // 'paypal' or 'card'
    bool _isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => SingleChildScrollView(
          child: Dialog(
            backgroundColor: const Color(0xFF1E293B), // Dark blue-grey
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Withdraw Funds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  const SizedBox(height: 8),

                  // Amount field
                  const Text(
                    'Amount (USD)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF334155), // Dark grey
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Enter amount',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixText: '\$',
                      prefixStyle: const TextStyle(color: Colors.white),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment method selection
                  const Text(
                    'Select Withdrawal Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment method tabs (side by side)
                  Row(
                    children: [
                      // PayPal button (left side)
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedPaymentMethod = 'paypal';
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedPaymentMethod == 'paypal'
                                  ? const Color(0xFFFFC439) // Gold when selected
                                  : const Color(
                                      0xFF334155,
                                    ), // Dark grey when not selected
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              border: Border.all(
                                color: selectedPaymentMethod == 'paypal'
                                    ? const Color(
                                        0xFF003087,
                                      ) // PayPal blue border when selected
                                    : Colors
                                          .grey[600]!, // Light grey border when not selected
                                width: 2,
                              ),
                              boxShadow: selectedPaymentMethod == 'paypal'
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFC439,
                                        ).withOpacity(0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // PayPal Icon
                                if (selectedPaymentMethod == 'paypal')
                                  SizedBox(
                                    width: 28,
                                    height: 20,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 0,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF003087), // Dark blue
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 8,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF009CDE), // Light blue
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: 28,
                                    height: 20,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 0,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[400],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 8,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[500],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  'PayPal',
                                  style: TextStyle(
                                    color: selectedPaymentMethod == 'paypal'
                                        ? const Color(
                                            0xFF003087,
                                          ) // PayPal blue when selected
                                        : Colors
                                              .grey[300], // Faded grey when not selected
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Card button (right side)
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedPaymentMethod = 'card';
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedPaymentMethod == 'card'
                                  ? const Color(0xFF1E40AF) // Dark blue when selected
                                  : const Color(
                                      0xFF334155,
                                    ), // Dark grey when not selected
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              border: Border.all(
                                color: selectedPaymentMethod == 'card'
                                    ? Colors.white
                                    : Colors
                                          .grey[600]!, // Light grey border when not selected
                                width: 2,
                              ),
                              boxShadow: selectedPaymentMethod == 'card'
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF1E40AF,
                                        ).withOpacity(0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Card Icon
                                Icon(
                                  Icons.credit_card,
                                  color: selectedPaymentMethod == 'card'
                                      ? Colors.white
                                      : Colors.grey[400],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Card',
                                  style: TextStyle(
                                    color: selectedPaymentMethod == 'card'
                                        ? Colors.white
                                        : Colors.grey[300], // Faded grey when not selected
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Show fields based on selected payment method
                  if (selectedPaymentMethod == 'paypal') ...[
                    // PayPal Email field
                    const Text(
                      'PayPal Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF334155), // Dark grey
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Enter PayPal email',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ] else if (selectedPaymentMethod == 'card') ...[
                    // Card Holder Name
                    const Text(
                      'Card Holder Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cardHolderController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Enter card holder name',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card Number
                    const Text(
                      'Card Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cardNumberController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintText: '1234 5678 9012 3456',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Expiry and CVV row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expiry Date',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: expiryController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF334155),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'MM/YY',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CVV',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: cvvController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF334155),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: '123',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Withdraw button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (amountController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter amount'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                                return;
                              }

                              final amount = double.tryParse(
                                amountController.text.trim(),
                              );
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a valid amount',
                                    ),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                                return;
                              }

                              if (selectedPaymentMethod == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a withdrawal method',
                                    ),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                                return;
                              }

                              // Validate payment method specific fields
                              if (selectedPaymentMethod == 'paypal') {
                                if (emailController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter PayPal email',
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                  return;
                                }
                              } else if (selectedPaymentMethod == 'card') {
                                if (cardHolderController.text.trim().isEmpty ||
                                    cardNumberController.text.trim().isEmpty ||
                                    expiryController.text.trim().isEmpty ||
                                    cvvController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please fill all card details',
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                  return;
                                }
                              }

                              setDialogState(() {
                                _isSubmitting = true;
                              });

                              try {
                                final amount = amountController.text.trim();
                                
                                debugPrint('💵 [WALLET SCREEN] Withdrawing funds:');
                                debugPrint('   → Amount: $amount');
                                debugPrint('   → Payment Method: $selectedPaymentMethod');
                                
                                Map<String, dynamic> withdrawData = {
                                  'amount': amount,
                                  'payment_method': selectedPaymentMethod,
                                };

                                // Add payment method specific data
                                if (selectedPaymentMethod == 'paypal') {
                                  final email = emailController.text.trim();
                                  withdrawData['email'] = email;
                                  debugPrint('   → PayPal Email: $email');
                                } else if (selectedPaymentMethod == 'card') {
                                  withdrawData['card_holder'] =
                                      cardHolderController.text.trim();
                                  withdrawData['card_number'] =
                                      cardNumberController.text.trim();
                                  withdrawData['expiry'] = expiryController.text
                                      .trim();
                                  withdrawData['cvv'] = cvvController.text
                                      .trim();
                                  debugPrint('   → Card Holder: ${cardHolderController.text.trim()}');
                                }

                                final response = await _apiService
                                    .withdrawFromWallet(withdrawData);

                                debugPrint('💵 [WALLET SCREEN] Withdraw response:');
                                debugPrint('   → Status Code: ${response.statusCode}');
                                debugPrint('   → Response: ${response.data}');

                                if (mounted) {
                                  Navigator.of(context).pop();

                                  // Check if response is successful (status code 200 or status field is success)
                                  final responseData = response.data;
                                  final isSuccess = response.statusCode == 200 ||
                                      (responseData != null &&
                                          responseData is Map &&
                                          (responseData['status'] == 'success' ||
                                              responseData['success'] == true));

                                  if (isSuccess) {
                                    // Reload wallet data
                                    await _loadWalletData();

                                    // Show success snackbar message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          responseData != null &&
                                                  responseData is Map
                                              ? (responseData['message']
                                                      ?.toString() ??
                                                  'Withdrawal submitted successfully!')
                                              : 'Withdrawal submitted successfully!',
                                        ),
                                        backgroundColor: AppTheme.successColor,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  } else {
                                    // Show error snackbar message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          responseData != null &&
                                                  responseData is Map
                                              ? (responseData['message']
                                                      ?.toString() ??
                                                  'Failed to submit withdrawal')
                                              : 'Failed to submit withdrawal',
                                        ),
                                        backgroundColor: AppTheme.errorColor,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED), // Purple
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Withdraw',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTopUp() async {
    final amountController = TextEditingController();
    String? selectedPaymentMethod; // 'paypal' or 'card'
    bool _isSubmitting = false;

    // Capture the parent context before showing dialog
    final parentContext = context;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top-up Wallet',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount field
                const Text(
                  'Amount (USD)',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Enter amount',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixText: '\$',
                    prefixStyle: const TextStyle(color: Color(0xFF1F2937)),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment method buttons
                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // PayPal button
                GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () {
                          setDialogState(() {
                            selectedPaymentMethod = 'paypal';
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selectedPaymentMethod == 'paypal'
                          ? const Color(0xFFFFC439) // Gold when selected
                          : const Color(
                              0xFFF3F4F6,
                            ), // Faded grey when not selected
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedPaymentMethod == 'paypal'
                            ? const Color(
                                0xFF003087,
                              ) // PayPal blue border when selected
                            : Colors
                                  .grey[300]!, // Light grey border when not selected
                        width: 2,
                      ),
                      boxShadow: selectedPaymentMethod == 'paypal'
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFC439).withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // PayPal Icon - Two tone blue circles (PayPal logo representation)
                        if (selectedPaymentMethod == 'paypal')
                          // Colored PayPal icon when selected
                          SizedBox(
                            width: 28,
                            height: 20,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF003087), // Dark blue
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF009CDE), // Light blue
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // Faded icon when not selected
                          SizedBox(
                            width: 28,
                            height: 20,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[500],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          'PayPal',
                          style: TextStyle(
                            color: selectedPaymentMethod == 'paypal'
                                ? const Color(
                                    0xFF003087,
                                  ) // PayPal blue when selected
                                : Colors
                                      .grey[600], // Faded grey when not selected
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (amountController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter amount'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            if (selectedPaymentMethod == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select a payment method',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            final amount = double.tryParse(
                              amountController.text.trim(),
                            );
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              _isSubmitting = true;
                            });

                            bool dialogPopped =
                                false; // Track if dialog was popped for PayPal flow

                            try {
                              final response = await _apiService
                                  .createWalletOrder({
                                    'balance': amountController.text.trim(),
                                    'payment_method': selectedPaymentMethod,
                                  });

                              debugPrint(
                                '💳 Wallet add balance response -> status: ${response.statusCode}, payment_method: $selectedPaymentMethod',
                              );
                              debugPrint(
                                '💳 Wallet add balance response data: ${response.data}',
                              );

                              if (mounted) {
                                if (response.statusCode == 200 ||
                                    response.statusCode == 201) {
                                  final responseData = response.data;

                                  // Handle PayPal redirect if approval link exists
                                  // Check BEFORE popping dialog to ensure context is valid
                                  if (selectedPaymentMethod == 'paypal' &&
                                      responseData != null &&
                                      responseData is Map) {
                                    // Try multiple locations for approval link
                                    dynamic rawApprovalLink;
                                    if (responseData['approvalLink'] != null) {
                                      rawApprovalLink =
                                          responseData['approvalLink'];
                                    } else if (responseData['approval_url'] !=
                                        null) {
                                      rawApprovalLink =
                                          responseData['approval_url'];
                                    } else if (responseData['approvalUrl'] !=
                                        null) {
                                      rawApprovalLink =
                                          responseData['approvalUrl'];
                                    } else if (responseData['data'] is Map) {
                                      final data = responseData['data'] as Map;
                                      rawApprovalLink =
                                          data['approvalLink'] ??
                                          data['approval_url'] ??
                                          data['approvalUrl'];
                                    }

                                    debugPrint(
                                      '💳 PayPal approval link: $rawApprovalLink',
                                    );

                                    if (rawApprovalLink != null &&
                                        rawApprovalLink.toString().isNotEmpty) {
                                      final approvalLink = rawApprovalLink
                                          .toString();

                                      // Pop dialog first
                                      Navigator.of(context).pop();

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Opening PayPal...'),
                                            backgroundColor:
                                                AppTheme.successColor,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );

                                        final paypalResult =
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PaypalWebViewScreen(
                                                      approvalUrl: approvalLink,
                                                    ),
                                              ),
                                            );

                                        // Handle PayPal return result
                                        if (mounted && paypalResult != null) {
                                          if (paypalResult is Map) {
                                            final isSuccess =
                                                paypalResult['success'] == true;

                                            if (isSuccess) {
                                              // Payment successful - wait a moment for backend to process, then reload wallet
                                              await Future.delayed(const Duration(seconds: 1));
                                              
                                              await _loadWalletData();
                                              await _loadTransactions();

                                              ScaffoldMessenger.of(
                                                parentContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    responseData['message']
                                                            ?.toString() ??
                                                        'Payment completed successfully! Your wallet balance has been updated.',
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.successColor,
                                                  duration: const Duration(
                                                    seconds: 4,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              // Payment cancelled or failed
                                              ScaffoldMessenger.of(
                                                parentContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Payment was cancelled',
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.errorColor,
                                                ),
                                              );
                                            }
                                          } else {
                                            // Fallback: reload wallet anyway
                                            await _loadWalletData();
                                            await _loadTransactions();
                                            ScaffoldMessenger.of(
                                              parentContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  responseData['message']
                                                          ?.toString() ??
                                                      'Payment processed. Please check your wallet balance.',
                                                ),
                                                backgroundColor:
                                                    AppTheme.successColor,
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      return;
                                    } else {
                                      debugPrint(
                                        '⚠️ PayPal selected but no approval link found in response',
                                      );
                                    }
                                  }

                                  // Pop dialog if not PayPal or no approval link
                                  // Only pop if dialog wasn't already popped for PayPal flow
                                  if (!dialogPopped) {
                                    try {
                                      if (Navigator.of(
                                        dialogContext,
                                      ).canPop()) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    } catch (popError) {
                                      debugPrint(
                                        '⚠️ [Wallet] Error popping dialog: $popError',
                                      );
                                    }
                                  }

                                  // Handle other payment methods if needed
                                  if (selectedPaymentMethod == 'card') {
                                    // TODO: Implement card payment flow
                                    ScaffoldMessenger.of(
                                      parentContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Card payment coming soon!',
                                        ),
                                        backgroundColor: AppTheme.successColor,
                                      ),
                                    );
                                  } else {
                                    // Show success message for non-PayPal payments
                                    ScaffoldMessenger.of(
                                      parentContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          responseData != null &&
                                                  responseData is Map
                                              ? responseData['message']
                                                        ?.toString() ??
                                                    'Payment processed successfully'
                                              : 'Payment processed successfully',
                                        ),
                                        backgroundColor: AppTheme.successColor,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }

                                  // Reload wallet data after a delay to allow payment processing
                                  await Future.delayed(
                                    const Duration(seconds: 2),
                                  );
                                  await _loadWalletData();
                                } else {
                                  Navigator.of(dialogContext).pop();
                                  ScaffoldMessenger.of(
                                    parentContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response.data['message']?.toString() ??
                                            'Failed to create order',
                                      ),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                try {
                                  // Try to pop dialog if it's still open
                                  final navigator = Navigator.of(
                                    dialogContext,
                                    rootNavigator: false,
                                  );
                                  if (navigator.canPop()) {
                                    navigator.pop();
                                  }
                                } catch (popError) {
                                  debugPrint(
                                    '⚠️ [Wallet] Error popping dialog: $popError',
                                  );
                                }

                                // Show error message using parent context
                                if (mounted) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      try {
                                        ScaffoldMessenger.of(
                                          parentContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error: ${e.toString()}',
                                            ),
                                            backgroundColor:
                                                AppTheme.errorColor,
                                          ),
                                        );
                                      } catch (scaffoldError) {
                                        debugPrint(
                                          '⚠️ [Wallet] Error showing SnackBar: $scaffoldError',
                                        );
                                      }
                                    }
                                  });
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSubmitting
                          ? Colors.grey
                          : const Color(0xFF7C3AED), // Purple
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Powered by PayPal
                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Powered by ',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'PayPal',
                        style: TextStyle(
                          color: Color(0xFF003087),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(current: 'wallet'),
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              TranslationService().translate('wallet.wallet'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        isDark: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: const [], // Remove profile icon
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : _walletData == null
          ? Center(child: TranslatedText('wallet.noWalletDataAvailable'))
          : _buildTabContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            TranslationService().translate('wallet.failedToLoadWallet'),
            style: TextStyle(fontSize: 18, color: AppTheme.errorColor),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadWalletData,
            child: TranslatedText('app.retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF2563EB), // Blue background for selected
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF1F2937),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: TranslationService().translate('wallet.wallet')),
              Tab(text: TranslationService().translate('wallet.transactions')),
            ],
          ),
        ),
        // Tab Bar View
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildWalletTab(), _buildTransactionsTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletTab() {
    final points = (_walletData!['points'] ?? 0) as num;

    return RefreshIndicator(
      onRefresh: _loadWalletData,
      color: const Color(0xFF7C3AED),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View Toggle Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TranslationService().translate('wallet.myWallets'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isListView = !_isListView;
                        if (_isListView) {
                          _stopAutoScroll();
                        } else {
                          _startAutoScroll();
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListView ? Icons.view_carousel : Icons.list,
                        size: 20,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Wallet Cards - Side View, List View, or Slider View
            _isListView
                ? _buildWalletListView(points)
                : _buildWalletSliderView(points),
            const SizedBox(height: 24),
            // Quick Actions Section
            _buildQuickActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletSliderView(num points) {
    // Start auto-scroll when slider view is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _walletPageController,
            onPageChanged: (index) {
              setState(() {
                _currentWalletIndex = index;
              });
              // Restart timer when page changes (user interaction)
              _startAutoScroll();
            },
            itemCount: 3,
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAppWalletCard(),
                  );
                case 1:
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildPointsCard(points),
                  );
                case 2:
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildEquxxWalletCard(),
                  );
                default:
                  return const SizedBox();
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        // Navigation Arrows and Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous Arrow
            IconButton(
              onPressed: _currentWalletIndex > 0
                  ? () {
                      _walletPageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      // Restart auto-scroll after manual navigation
                      _startAutoScroll();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
              color: _currentWalletIndex > 0
                  ? const Color(0xFF2563EB)
                  : Colors.grey,
              iconSize: 28,
            ),
            const SizedBox(width: 16),
            // Page Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentWalletIndex == index ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentWalletIndex == index
                        ? const Color(0xFF2563EB)
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(width: 16),
            // Next Arrow
            IconButton(
              onPressed: _currentWalletIndex < 2
                  ? () {
                      _walletPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      // Restart auto-scroll after manual navigation
                      _startAutoScroll();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
              color: _currentWalletIndex < 2
                  ? const Color(0xFF2563EB)
                  : Colors.grey,
              iconSize: 28,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletListView(num points) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // App Wallet Card - Compact List View
          _buildAppWalletCardCompact(),
          const SizedBox(height: 12),
          // Points Card - Compact List View
          _buildPointsCardCompact(points),
          const SizedBox(height: 12),
          // EQUXX Wallet Card - Compact List View
          _buildEquxxWalletCardCompact(),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadWalletData();
        await _loadTransactions();
      },
      color: const Color(0xFF7C3AED),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Transactions Section
            _buildTransactionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppWalletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A5F), // Dark blue
            Color(0xFF2D4A6B), // Slightly lighter dark blue
            Color(0xFF3A5A7D), // Medium blue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular Profile Icon with Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37), // Gold
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700), // Light gold
                        width: 2.5,
                      ),
                      color: const Color(
                        0xFFFFF8DC,
                      ), // Cream/off-white background
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/mobile/wallet_icon.png', // You can replace this with your baby icon image
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover, // This allows zooming/scaling
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to app icon if wallet_icon.png doesn't exist
                          return Image.asset(
                            'AppIcons/playstore.png',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFFF8DC),
                                ),
                                child: const Icon(
                                  Icons.account_circle,
                                  color: Color(0xFF8B4513),
                                  size: 40,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Wallet Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'APP WALLET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${_formatBalance(_walletData?['balance'] ?? 0)}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700), // Bright yellow/gold
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'WALLET BALANCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Golden Divider Line
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4AF37), // Gold
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Bottom Section - Email
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  final email =
                      _walletData?['email']?.toString() ?? 'user@gmail.com';
                  await Clipboard.setData(ClipboardData(text: email));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email copied to clipboard'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF1E3A5F,
                    ).withOpacity(0.8), // Dark blue
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(
                        0xFFD4AF37,
                      ).withOpacity(0.3), // Gold border
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Email : ${_walletData?['email']?.toString() ?? 'user@gmail.com'}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700), // Gold/yellow
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.copy,
                        color: Color(0xFFFFD700), // Gold/yellow
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEquxxWalletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A5F), // Dark blue
            Color(0xFF2D4A6B), // Slightly lighter dark blue
            Color(0xFF3A5A7D), // Medium blue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular Icon with EQUXX Logo Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37), // Gold
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700), // Light gold
                        width: 2.5,
                      ),
                      color: const Color(0xFF1E3A5F), // Dark blue background
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/mobile/equxx icon logo.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1E3A5F),
                            ),
                            child: const Center(
                              child: Text(
                                'E',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Wallet Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EQUXX WALLET',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '€00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'EQUXX BALANCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Golden Divider Line
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4AF37), // Gold
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Bottom spacing
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPointsCard(num points) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9333EA), // Purple
            Color(0xFFA855F7), // Lighter purple
            Color(0xFFC084FC), // Pinkish-purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular Icon with Points/Diamond Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/mobile/points icon.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.diamond,
                              color: Color(0xFF3B82F6),
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Points Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POINTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${points.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'AVAILABLE POINTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider Line
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Bottom Section - Point conversion info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF7C3AED,
                  ).withOpacity(0.6), // Darker purple
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Point = \$1 | 1:1',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Compact List View Methods
  Widget _buildAppWalletCardCompact() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A5F), // Dark blue
            Color(0xFF2D4A6B), // Slightly lighter dark blue
            Color(0xFF3A5A7D), // Medium blue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                  color: const Color(0xFFFFF8DC),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/mobile/wallet_icon.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'AppIcons/playstore.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFF8DC),
                            ),
                            child: const Icon(
                              Icons.account_circle,
                              color: Color(0xFF8B4513),
                              size: 28,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Wallet Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'APP WALLET',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_formatBalance(_walletData?['balance'] ?? 0)}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCardCompact(num points) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9333EA), // Purple
            Color(0xFFA855F7), // Lighter purple
            Color(0xFFC084FC), // Pinkish-purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/mobile/points icon.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.diamond,
                          color: Color(0xFF3B82F6),
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Points Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POINTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${points.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquxxWalletCardCompact() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A5F), // Dark blue
            Color(0xFF2D4A6B), // Slightly lighter dark blue
            Color(0xFF3A5A7D), // Medium blue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                  color: const Color(0xFF1E3A5F),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/mobile/equxx icon logo.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E3A5F),
                        ),
                        child: const Center(
                          child: Text(
                            'E',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Wallet Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EQUXX WALLET',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '€00',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on_rounded, color: Color(0xFF6366F1), size: 22),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Buy Points',
                  Icons.credit_card_rounded,
                  [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  _handleBuyPoints,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildActionButton('Send', Icons.send_rounded, [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ], _handleSend),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Withdraw',
                  Icons.account_balance_wallet_rounded,
                  [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
                  _handleWithdraw,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildActionButton('Top-up', Icons.add_circle_rounded, [
                  const Color(0xFF2563EB),
                  const Color(0xFF6366F1),
                ], _handleTopUp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    if (_isLoadingTransactions) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final transactions = _transactions;

    debugPrint(
      '📊 [Wallet] Building transactions section with ${transactions.length} transactions',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationService().translate('wallet.transactions'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          // Table Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationService().translate('wallet.transaction'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  TranslationService().translate('wallet.amount'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          // Transaction List
          ...transactions.map(
            (transaction) => _buildTransactionItem(transaction),
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      TranslationService().translate(
                        'wallet.noTransactionsYet',
                      ),
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCredit = transaction['isCredit'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFFD1FAE5) // Green 100
                  : const Color(0xFFFEE2E2), // Red 100
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isCredit ? Colors.green : Colors.red).withOpacity(
                    0.1,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.attach_money,
              color: isCredit
                  ? const Color(0xFF059669) // Green 600
                  : const Color(0xFFDC2626), // Red 600
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['id'] ?? 'Transaction',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                if (transaction['type'] != null)
                  Text(
                    transaction['type'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '\$${transaction['amount']}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isCredit
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
