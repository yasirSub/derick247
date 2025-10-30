import 'package:flutter/material.dart';
import 'dart:async';
import '../config/theme_config.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/products/product_detail_screen.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? title;
  final bool isDark;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? titleWidget;
  final Widget? flexibleSpace;
  final bool showSearchBar;
  final Function(String)? onSearchSubmitted;
  final String? searchHint;

  const CustomAppBar({
    Key? key,
    this.title,
    this.isDark = false,
    this.leading,
    this.actions,
    this.titleWidget,
    this.flexibleSpace,
    this.showSearchBar = false,
    this.onSearchSubmitted,
    this.searchHint,
  }) : super(key: key);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  bool _showClearButton = false;
  bool _showSuggestions = false;
  List<Product> _searchSuggestions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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
      setState(() {
        _searchExpanded = true;
      });
      _showSearchOverlay();
    } else {
      setState(() {
        _searchExpanded = false;
      });
      // Delay removal to allow tap on suggestions
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus && mounted) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _showClearButton = query.isNotEmpty;
    });

    // Debounce search API calls
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
    if (query.length < 2) return; // Don't search for very short queries

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await ApiService().getProducts(
        page: 1,
        limit: 5, // Limit to 5 suggestions
        search: query,
      );

      if (response.statusCode == 200 && mounted) {
        List<dynamic> dataList = [];

        if (response.data['data'] != null) {
          if (response.data['data'] is List) {
            dataList = response.data['data'] as List;
          } else if (response.data['data']['data'] is List) {
            dataList = response.data['data']['data'] as List;
          } else if (response.data['data']['products'] is List) {
            dataList = response.data['data']['products'] as List;
          }
        }

        if (dataList.isEmpty && response.data is List) {
          dataList = response.data as List;
        }

        final suggestions = dataList
            .map((item) {
              try {
                return Product.fromJson(item);
              } catch (e) {
                return null;
              }
            })
            .whereType<Product>()
            .toList();

        if (mounted) {
          setState(() {
            _searchSuggestions = suggestions;
            _showSuggestions = suggestions.isNotEmpty;
          });
          if (_searchFocusNode.hasFocus) {
            _showSearchOverlay();
          }
        }
      }
    } catch (e) {
      print('Error searching: $e');
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

    final screenWidth = MediaQuery.of(context).size.width;
    final searchBarWidth = screenWidth - 32 - 16; // Account for margins

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: searchBarWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              width: searchBarWidth,
              constraints: const BoxConstraints(maxHeight: 400),
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
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _searchSuggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No products found',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchSuggestions.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final product = _searchSuggestions[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 50,
                              maxHeight: 50,
                            ),
                            child: product.firstImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      product.firstImage!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image,
                                                size: 24,
                                              ),
                                            );
                                          },
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image, size: 24),
                                  ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            product.formattedPrice,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            _searchController.clear();
                            _removeOverlay();
                            _searchFocusNode.unfocus();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  productId: product.id,
                                  product: product,
                                ),
                              ),
                            );
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDark
        ? AppTheme.darkAppBarColor
        : AppTheme.lightAppBarColor;
    final foregroundColor = widget.isDark ? Colors.white : AppTheme.textColor;

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      leading: widget.leading,
      titleSpacing: widget.showSearchBar ? 0 : null,
      title: widget.showSearchBar
          ? _buildSearchBar(context)
          : (widget.titleWidget ??
                (widget.title != null ? Text(widget.title!) : null)),
      actions: widget.actions ?? _buildDefaultActions(context, foregroundColor),
      flexibleSpace: widget.flexibleSpace,
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 270),
        curve: Curves.easeInOutCubic,
        width: _searchExpanded ? 240 : 114,
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (!_searchExpanded) {
              setState(() {
                _searchExpanded = true;
              });
              FocusScope.of(context).requestFocus(_searchFocusNode);
            }
          },
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.search, color: Colors.grey[600], size: 22),
              ),
              if (_searchExpanded) ...[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: widget.searchHint ?? 'Search products...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      isDense: true,
                      suffixIcon: _showClearButton
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showClearButton = false;
                                });
                                _removeOverlay();
                              },
                            )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _removeOverlay();
                        _handleSearch(context, value.trim());
                      }
                    },
                    onTap: () {
                      if (_searchController.text.isNotEmpty &&
                          _showSuggestions) {
                        _showSearchOverlay();
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleSearch(BuildContext context, String query) {
    // Navigate to products screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          // Set search query before building the screen
          final productProvider = Provider.of<ProductProvider>(
            context,
            listen: false,
          );
          productProvider.searchProducts(query);

          return ProductsScreen(categoryName: 'Search Results');
        },
      ),
    );
  }

  List<Widget> _buildDefaultActions(BuildContext context, Color iconColor) {
    return [
      Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoggedIn) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    color: AppTheme.darkAppBarColor,
                    size: 20,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ];
  }
}
