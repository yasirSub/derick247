import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/translated_text.dart';
import '../../services/translation_service.dart';
import '../../config/theme_config.dart';
import 'order_details_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<dynamic> _orders = [];
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _searchQuery;

  // Search suggestions
  List<String> _searchSuggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _searchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChange);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
      _showSearchOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus && mounted) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Debounce search API calls for suggestions
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 1) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Fetch suggestions from orders API
      final response = await ApiService().getOrders(
        page: 1,
        limit: 5, // Limit to 5 suggestions
        search: query,
      );

      if (response.statusCode == 200 && mounted) {
        List<dynamic> orders = [];
        dynamic body = response.data;
        if (body is String) {
          body = json.decode(body);
        }

        if (body is Map<String, dynamic> && body['success'] == true) {
          final data = body['data'];
          if (data is Map<String, dynamic> && data['data'] is List) {
            orders = data['data'] as List;
          } else if (data is List) {
            orders = data;
          }
        }

        // Extract order IDs/numbers as suggestions
        final suggestions = orders
            .map((order) {
              final orderId = order['order_id'] ?? order['id'] ?? '';
              return orderId.toString();
            })
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        if (mounted) {
          setState(() {
            _searchSuggestions = suggestions;
            _showSuggestions =
                suggestions.isNotEmpty && _searchFocusNode.hasFocus;
          });
          if (_searchFocusNode.hasFocus) {
            _showSearchOverlay();
          }
        }
      }
    } catch (e) {
      print('Error getting search suggestions: $e');
      if (mounted) {
        setState(() {
          _searchSuggestions = [];
          _showSuggestions = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showSearchOverlay() {
    if (!_showSuggestions && !_isSearching) {
      _removeOverlay();
      return;
    }

    _removeOverlay();

    final box = _searchKey.currentContext?.findRenderObject() as RenderBox?;
    final searchBarWidth =
        box?.size.width ?? MediaQuery.of(context).size.width - 32;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: searchBarWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              width: searchBarWidth,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _searchSuggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        TranslationService().translate(
                              'orders.noSuggestions',
                            ) ??
                            'No suggestions',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchSuggestions.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Icon(
                            Icons.receipt_long,
                            color: Colors.orange,
                            size: 20,
                          ),
                          title: Text(
                            'Order #$suggestion',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          onTap: () {
                            _searchController.text = suggestion;
                            setState(() {
                              _searchQuery = suggestion;
                            });
                            _removeOverlay();
                            _searchFocusNode.unfocus();
                            _loadOrders(refresh: true);
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadOrders({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _orders.clear();
        _hasMore = true;
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final Response res = await ApiService().getOrders(
        page: _currentPage,
        limit: 10,
        search: _searchQuery?.isNotEmpty == true ? _searchQuery : null,
      );
      dynamic body = res.data;
      if (body is String) {
        body = json.decode(body);
      }

      if (body is Map<String, dynamic> && body['success'] == true) {
        List<dynamic> orders = [];
        final data = body['data'];

        print('Orders API response structure: ${data.runtimeType}');

        if (data is Map<String, dynamic>) {
          // Check if API returns paginated response with 'data' field
          if (data['data'] is List) {
            orders = data['data'] as List;
            print('Found ${orders.length} orders in data.data');
          }
          // Check for pagination metadata
          if (data['current_page'] != null) {
            final currentPage = data['current_page'] as int;
            final lastPage = data['last_page'] as int? ?? currentPage;
            final total = data['total'] as int? ?? orders.length;

            _hasMore = currentPage < lastPage;
            print('Pagination: page $currentPage/$lastPage, total: $total');
          } else if (data['total'] != null) {
            // Fallback: check if total count indicates more pages
            final total = data['total'] as int;
            _hasMore = _orders.length + orders.length < total;
          } else {
            // If no pagination info, assume no more if less than limit
            _hasMore = orders.length >= 10;
          }
        } else if (data is List) {
          // Fallback: if data is directly a list
          orders = data;
          print('Found ${orders.length} orders in data');
          // If no pagination info, assume no more if less than limit
          _hasMore = orders.length >= 10;
        } else {
          print('Unexpected data structure: $data');
        }

        setState(() {
          if (refresh || _currentPage == 1) {
            _orders = orders;
          } else {
            _orders.addAll(orders);
          }
          _loading = false;
        });
      } else {
        print('API response missing success or unexpected format: $body');
        setState(() {
          _error = TranslationService().translate(
            'orders.unexpectedApiResponse',
          );
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = TranslationService().translate(
          'orders.failedToLoadOrders',
          params: {'error': e.toString()},
        );
        _loading = false;
      });
      print('Error loading orders: $e');
      if (e is DioException) {
        print('Response: ${e.response?.data}');
        print('Status: ${e.response?.statusCode}');
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
    });

    _currentPage++;

    try {
      final Response res = await ApiService().getOrders(
        page: _currentPage,
        limit: 10,
        search: _searchQuery?.isNotEmpty == true ? _searchQuery : null,
      );
      dynamic body = res.data;
      if (body is String) {
        body = json.decode(body);
      }

      if (body is Map<String, dynamic> && body['success'] == true) {
        List<dynamic> orders = [];
        final data = body['data'];

        if (data is Map<String, dynamic> && data['data'] is List) {
          orders = data['data'] as List;
        } else if (data is List) {
          orders = data;
        }

        // Check for pagination metadata
        if (data is Map<String, dynamic>) {
          if (data['current_page'] != null) {
            final currentPage = data['current_page'] as int;
            final lastPage = data['last_page'] as int? ?? currentPage;
            _hasMore = currentPage < lastPage;
          } else if (data['total'] != null) {
            final total = data['total'] as int;
            _hasMore = _orders.length + orders.length < total;
          } else {
            _hasMore = orders.length >= 10;
          }
        } else {
          _hasMore = orders.length >= 10;
        }

        setState(() {
          _orders.addAll(orders);
          _loadingMore = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingMore = false;
        _currentPage--; // Revert page on error
      });
      print('Error loading more orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: const AppDrawer(current: 'orders'),
      appBar: CustomAppBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long, color: Colors.white, size: 24),
            SizedBox(width: 8),
            TranslatedText(
              'orders.orders',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        isDark: true,
        actions: [], // Remove default profile icon
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: _searchKey,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: TranslationService().translate('orders.searchOrders'),
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 22),
            suffixIcon: _searchQuery?.isNotEmpty == true
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = null;
                      });
                      _removeOverlay();
                      _loadOrders(refresh: true);
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().isEmpty ? null : value.trim();
            });
          },
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              setState(() {
                _searchQuery = value.trim();
              });
              _removeOverlay();
              _searchFocusNode.unfocus();
              _loadOrders(refresh: true);
            }
          },
          onTap: () {
            if (_searchController.text.isNotEmpty && _showSuggestions) {
              _showSearchOverlay();
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Search Bar - Always visible at top
        _buildSearchBar(),
        // Content area
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              TranslationService().translate('orders.loadingOrders'),
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _loadOrders(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
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
                      child: Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      TranslationService().translate(
                        'orders.somethingWentWrong',
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _loadOrders(refresh: true),
                      icon: const Icon(Icons.refresh),
                      label: TranslatedText('common.retry'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadOrders(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
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
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _searchQuery != null
                        ? TranslationService().translate(
                                'orders.noOrdersFound',
                              ) ??
                              'No orders found'
                        : TranslationService().translate('orders.noOrdersYet'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery != null
                        ? TranslationService().translate(
                                'orders.tryDifferentSearch',
                              ) ??
                              'Try a different search term'
                        : TranslationService().translate(
                            'orders.ordersWillAppearHere',
                          ),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _loadOrders(refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: TranslatedText('common.refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

    return RefreshIndicator(
      onRefresh: () => _loadOrders(refresh: true),
      color: Colors.orange,
      child: Column(
        children: [
          // Header with order count
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Text(
                  '${_orders.length} ${_orders.length == 1 ? TranslationService().translate('orders.order') : TranslationService().translate('orders.ordersPlural')}',
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length + (_loadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _orders.length) {
                  // Loading indicator at the bottom
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
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
    final orderDate = (order['order_date'] ?? order['created_at'] ?? '')
        .toString();
    final paymentStatus = (order['payment_status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final orderStatus = (order['order_status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final totalAmount = (order['total_amount'] ?? order['total'] ?? '0')
        .toString();
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
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
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
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[600],
                              ),
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
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$itemCount ${itemCount == 1 ? TranslationService().translate('orders.item') : TranslationService().translate('orders.items')}',
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
                          '${TranslationService().translate('orders.total')}: ',
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
                      TranslationService().translate('orders.viewDetails'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.orange.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String status,
    Color color,
    IconData icon, {
    bool isOrder = false,
  }) {
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
    if (dateStr.isEmpty)
      return TranslationService().translate('orders.dateNotAvailable');
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
