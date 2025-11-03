import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import 'add_address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  Map<String, dynamic>? _checkoutData;

  // Selected values
  int? _selectedShippingAddressId;
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  Future<void> _loadCheckoutData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCheckout();

      if (response.statusCode == 200) {
        setState(() {
          _checkoutData = response.data['data'];
          // Auto-select first shipping address if available
          if (_checkoutData?['shipping_address'] != null &&
              (_checkoutData!['shipping_address'] as List).isNotEmpty) {
            _selectedShippingAddressId =
                _checkoutData!['shipping_address'][0]['id'];
          }
          // Auto-select first payment method if available
          if (_checkoutData?['payment_methods'] != null) {
            final paymentMethods = _checkoutData!['payment_methods'] as Map;
            if (paymentMethods.containsKey('wallet')) {
              _selectedPaymentMethod = 'wallet';
            } else if (paymentMethods.containsKey('paypal_checkout')) {
              _selectedPaymentMethod = 'paypal_checkout';
            }
          }
        });
      } else {
        setState(() {
          _error = response.data['message']?.toString() ??
              'Failed to load checkout information';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitCheckout() async {
    if (_selectedShippingAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a shipping address'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final checkoutData = <String, dynamic>{
        'shipping_address_id': _selectedShippingAddressId,
        'payment_method': _selectedPaymentMethod,
      };

      final response = await _apiService.checkout(checkoutData);

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Clear cart
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.clearCart();

        if (mounted) {
          // Navigate back and show success message
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['message']?.toString() ??
                    'Order placed successfully!',
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        final errorMessage = response.data['message']?.toString() ??
            'Failed to process checkout. Please try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process checkout: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _addNewShippingAddress() async {
    // Navigate to add address screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddAddressScreen(),
      ),
    );

    // If address was added successfully, reload checkout data
    if (result == true) {
      await _loadCheckoutData();
    }
  }

  double _calculateTotal() {
    if (_checkoutData == null || _checkoutData!['cart_items'] == null) {
      return 0.0;
    }

    final cartItems = _checkoutData!['cart_items'] as List;
    double total = 0.0;
    for (var item in cartItems) {
      total += (item['subtotal'] as num).toDouble();
    }
    return total;
  }

  String _getCurrencySymbol() {
    if (_checkoutData == null ||
        _checkoutData!['cart_items'] == null ||
        (_checkoutData!['cart_items'] as List).isEmpty) {
      return 'L';
    }
    return _checkoutData!['cart_items'][0]['currency_symbol'] ?? 'L';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_bag, color: Colors.orange[700], size: 28),
            const SizedBox(width: 8),
            const Text(
              'Secure Checkout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.darkAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _checkoutData == null
                  ? const Center(child: Text('No checkout data available'))
                  : _buildCheckoutContent(),
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
            'Failed to load checkout',
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
            onPressed: _loadCheckoutData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutContent() {
    final cartItems = _checkoutData!['cart_items'] as List? ?? [];
    final shippingAddresses =
        _checkoutData!['shipping_address'] as List? ?? [];
    final paymentMethods = _checkoutData!['payment_methods'] as Map? ?? {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Items Section
          if (cartItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Text(
                'Order Items',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return _buildCartItemCard(item);
              },
            ),
          ],

          // Shipping Details Section
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.orange[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Shipping Details',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Existing Shipping Addresses
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shippingAddresses.length,
            itemBuilder: (context, index) {
              final address = shippingAddresses[index];
              return _buildShippingAddressCard(address);
            },
          ),
          
          // Add New Address Card (dashed border)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
            child: GestureDetector(
              onTap: _addNewShippingAddress,
              child: Container(
                margin: const EdgeInsets.only(top: AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[400]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                padding: const EdgeInsets.all(AppTheme.spacingLarge * 2),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 48,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Text(
                      'Add New Address',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      'Tap to add a new address',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Payment Methods Section
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Text(
              'Payment Method',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paymentMethods.length,
            itemBuilder: (context, index) {
              final entry = paymentMethods.entries.elementAt(index);
              return _buildPaymentMethodCard(entry.key, entry.value);
            },
          ),

          // Order Summary
          _buildOrderSummary(),

          // Submit Button
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'PLACE ORDER',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.fontSizeMedium,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: ListTile(
        leading: item['thumbnail'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['thumbnail'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image),
                ),
              )
            : const Icon(Icons.image),
        title: Text(item['product_name'] ?? 'Product'),
        subtitle: Text('Qty: ${item['quantity']}'),
        trailing: Text(
          '${item['currency_symbol'] ?? 'L'}${(item['subtotal'] as num).toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppTheme.fontSizeMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildShippingAddressCard(Map<String, dynamic> address) {
    final isSelected = _selectedShippingAddressId == address['id'];
    final isDefault = address['is_default'] == true || address['is_default'] == 1;
    
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedShippingAddressId = address['id'];
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient Name
                  Text(
                    address['recipient_name'] ?? '',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeMedium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  
                  // Phone
                  if (address['phone'] != null)
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          address['phone']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeSmall,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  
                  // Address
                  if (address['address'] != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 16, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address['address']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeSmall,
                              color: AppTheme.textSecondaryColor,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  
                  // Address Type
                  if (address['address_type'] != null)
                    Text(
                      'Address Type: ${address['address_type']}',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        color: AppTheme.textSecondaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              
              // Selection indicator and default badge
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[700]!),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    if (isDefault) const SizedBox(width: 8),
                    if (isSelected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.orange[700],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(String methodKey, Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == methodKey;
    
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPaymentMethod = methodKey;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              // Payment Icon
              if (methodKey == 'paypal_checkout')
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/images/paypal.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.payment,
                      color: Colors.blue[700],
                    ),
                  ),
                )
              else if (methodKey == 'wallet')
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.orange[700],
                    size: 32,
                  ),
                ),
              const SizedBox(width: AppTheme.spacingMedium),
              
              // Payment Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method['name'] ?? methodKey,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (methodKey == 'wallet' && method['balance'] != null)
                      Text(
                        'Use your existing balance',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeSmall,
                          color: AppTheme.textSecondaryColor,
                        ),
                      )
                    else if (methodKey == 'paypal_checkout')
                      Text(
                        'Fast & Secure Checkout',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeSmall,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.orange[700],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final total = _calculateTotal();
    final currencySymbol = _getCurrencySymbol();

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMedium),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal:',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeMedium,
                  color: Colors.white,
                ),
              ),
              Text(
                '$currencySymbol${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '$currencySymbol${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

