import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';
import '../../config/theme_config.dart';
import 'order_details_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Response res = await ApiService().getOrders();
      dynamic body = res.data;
      if (body is String) {
        body = json.decode(body);
      }

      if (body is Map<String, dynamic> && body['success'] == true) {
        List<dynamic> orders = [];
        final data = body['data'];
        
        print('Orders API response structure: ${data.runtimeType}');
        
        if (data is Map<String, dynamic> && data['data'] is List) {
          // API returns { success: true, data: { data: [...], ... } }
          orders = data['data'] as List;
          print('Found ${orders.length} orders in data.data');
        } else if (data is List) {
          // Fallback: if data is directly a list
          orders = data;
          print('Found ${orders.length} orders in data');
        } else {
          print('Unexpected data structure: $data');
        }

        setState(() {
          _orders = orders;
          _loading = false;
        });
      } else {
        print('API response missing success or unexpected format: $body');
        setState(() {
          _error = 'Unexpected API response';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders: ${e.toString()}';
        _loading = false;
      });
      print('Error loading orders: $e');
      if (e is DioException) {
        print('Response: ${e.response?.data}');
        print('Status: ${e.response?.statusCode}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: const AppDrawer(current: 'orders'),
      appBar: CustomAppBar(
        title: 'Orders',
        isDark: true,
        actions: [], // Remove default profile icon
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading orders...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              ),
              const SizedBox(height: 20),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your orders will appear here',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _loadOrders,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: Colors.orange,
      child: Column(
        children: [
          // Header with order count
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  '${_orders.length} ${_orders.length == 1 ? 'order' : 'orders'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index] as Map<String, dynamic>;
                return _buildOrderCard(order);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['id'] ?? 0;
    final orderDate = (order['order_date'] ?? order['created_at'] ?? '').toString();
    final paymentStatus = (order['payment_status'] ?? 'pending').toString().toLowerCase();
    final orderStatus = (order['order_status'] ?? 'pending').toString().toLowerCase();
    final totalAmount = (order['total_amount'] ?? order['total'] ?? '0').toString();
    final currency = (order['currency_symbol'] ?? '\$').toString();
    final itemCount = order['order_items'] ?? 0;

    // Status colors
    Color paymentColor;
    Color orderColor;
    IconData paymentIcon;
    
    if (paymentStatus == 'success') {
      paymentColor = const Color(0xFF16A34A);
      paymentIcon = Icons.check_circle;
    } else {
      paymentColor = const Color(0xFFF59E0B);
      paymentIcon = Icons.pending;
    }
    
    if (orderStatus == 'shipped' || orderStatus == 'completed') {
      orderColor = const Color(0xFF3B82F6);
    } else if (orderStatus == 'processing') {
      orderColor = const Color(0xFF8B5CF6);
    } else {
      orderColor = const Color(0xFF6B7280);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsScreen(orderId: orderId as int),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Order icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long, color: Colors.orange.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    // Order info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(orderDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStatusBadge(
                          paymentStatus,
                          paymentColor,
                          paymentIcon,
                        ),
                        const SizedBox(height: 6),
                        if (orderStatus != paymentStatus)
                          _buildStatusBadge(
                            orderStatus,
                            orderColor,
                            Icons.local_shipping,
                            isOrder: true,
                          ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                
                // Footer row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Item count
                    Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Total amount
                    Row(
                      children: [
                        Text(
                          'Total: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$currency$totalAmount',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                // View details hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.orange.shade700),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color, IconData icon, {bool isOrder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Date not available';
    try {
      // Handle format like "2025-10-21" or "2025-10-21/13:56:22"
      final parts = dateStr.split('/');
      final datePart = parts[0];
      final dateParts = datePart.split('-');
      if (dateParts.length == 3) {
        final year = dateParts[0];
        final month = dateParts[1];
        final day = dateParts[2];
        return '$day/$month/$year';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }
}

