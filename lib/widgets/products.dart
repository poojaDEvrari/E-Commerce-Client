import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import '../services/cart_service.dart';

class ProductsSection extends StatefulWidget {
  final VoidCallback? refreshCartCount;
  final bool isGuestMode;

  const ProductsSection({
    Key? key, 
    this.refreshCartCount,
    this.isGuestMode = false, // Default to false for backward compatibility
  }) : super(key: key);

  @override
  ProductsSectionState createState() => ProductsSectionState();
}

class ProductsSectionState extends State<ProductsSection> {
  List<dynamic> products = [];
  bool isLoading = true;
  String? error;
  Map<String, int> cartQuantities = {};

  @override
  void initState() {
    super.initState();
    fetchProducts();
    if (!widget.isGuestMode) {
      loadCartQuantities();
    }
  }

  Future<void> loadCartQuantities() async {
    try {
      final cartItems = await CartService.getCartItems();
      setState(() {
        cartQuantities.clear();
        for (var item in cartItems) {
          String productId = item['_id']?.toString() ?? item['productId']?.toString() ?? item['id']?.toString() ?? '';
          if (productId.isNotEmpty) {
            cartQuantities[productId] = item['quantity'] ?? 1;
          }
        }
      });
    } catch (e) {
      print('Error loading cart quantities: $e');
    }
  }

  Future<void> refreshProducts() async {
    await fetchProducts();
    if (!widget.isGuestMode) {
      await loadCartQuantities();
    }
  }

  Future<void> fetchProducts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/items'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data is List) {
            products = data;
          } else if (data is Map && data.containsKey('items')) {
            products = data['items'];
          } else if (data is Map && data.containsKey('data')) {
            products = data['data'];
          } else {
            products = [data];
          }
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load products: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> addItemToCart(dynamic product) async {
    if (widget.isGuestMode) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    try {
      await CartService.addToCart(Map<String, dynamic>.from(product));
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      // Refresh cart quantities from backend to ensure accuracy
      await loadCartQuantities();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
      if (widget.refreshCartCount != null) {
        widget.refreshCartCount!();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item to cart: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  Future<void> removeItemFromCart(dynamic product) async {
    try {
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      int currentQuantity = cartQuantities[productId] ?? 0;
      if (currentQuantity > 0) {
        if (currentQuantity == 1) {
          // Remove item completely
          await CartService.removeFromCart(productId);
        } else {
          // Decrease quantity
          await CartService.updateQuantity(productId, currentQuantity - 1);
        }
        // Refresh cart quantities from backend
        await loadCartQuantities();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product['name']} ${currentQuantity == 1 ? 'removed from' : 'quantity decreased in'} cart'),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
        if (widget.refreshCartCount != null) {
          widget.refreshCartCount!();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating cart: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fresh Products',
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await refreshProducts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Products refreshed!'),
                              backgroundColor: Colors.green.shade600,
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.green.shade700,
                          size: screenWidth > 600 ? 20 : 18,
                        ),
                        tooltip: 'Refresh Products',
                      ),
                      TextButton(
                        onPressed: () {
                          if (widget.isGuestMode) {
                            Navigator.pushNamed(context, '/login');
                          } else {
                            Navigator.pushNamed(context, '/search');
                          }
                        },
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: screenWidth > 600 ? 14 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading fresh products...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.red.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => refreshProducts(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (products.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No products available',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => refreshProducts(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 12,
                    childAspectRatio: _getChildAspectRatio(screenWidth),
                  ),
                  itemCount: products.length > 15 ? 15 : products.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(products[index], screenWidth);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth > 1200) {
      return 0.85; // Extra large screens - more space for content
    } else if (screenWidth > 900) {
      return 0.82; // Large screens
    } else if (screenWidth > 600) {
      return 0.80; // Medium screens
    } else if (screenWidth > 400) {
      return 0.78; // Small screens
    } else {
      return 0.75; // Very small screens - more height to prevent overflow
    }
  }

  Widget _buildProductCard(dynamic product, double screenWidth) {
    String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
    int quantity = cartQuantities[productId] ?? 0;
    
    return GestureDetector(
      onTap: () {
        if (widget.isGuestMode) {
          Navigator.pushNamed(context, '/login');
        } else {
          // Navigate to showcase page with product data
          Navigator.pushNamed(
            context, 
            '/showcase',
            arguments: product,
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image - Adjusted flex to give more space to content
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                      ? Image.network(
                          product['imageUrl'].toString(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        )
                      : _buildPlaceholderImage(),
                ),
              ),
            ),
            // Card Content - Increased flex and improved layout
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.all(screenWidth > 600 ? 10 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product Name - Better text handling
                    Flexible(
                      child: Text(
                        product['name']?.toString() ?? 'Unknown Product',
                        style: TextStyle(
                          fontSize: screenWidth > 600 ? 13 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Category - Smaller font to save space
                    if (product['category']?.toString().isNotEmpty == true)
                      Text(
                        product['category']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: screenWidth > 600 ? 10 : 9,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Price - Improved layout
                    Flexible(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '₹${product['price']?.toString() ?? '0'}',
                              style: TextStyle(
                                fontSize: screenWidth > 600 ? 13 : 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          Text(
                            '/${product['unit']?.toString() ?? 'unit'}',
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 9 : 8,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Cart Controls - Improved sizing
                    _buildCartControls(product, quantity, screenWidth),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartControls(dynamic product, int quantity, double screenWidth) {
    double buttonHeight = screenWidth > 600 ? 30 : 26;
    
    if (quantity == 0) {
      return SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: InkWell(
          onTap: () => addItemToCart(product),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_shopping_cart, 
                  size: screenWidth > 600 ? 12 : 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add to Cart',
                  style: TextStyle(
                    fontSize: screenWidth > 600 ? 10 : 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: buttonHeight,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green.shade700, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => removeItemFromCart(product),
                child: Container(
                  width: buttonHeight,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      bottomLeft: Radius.circular(5),
                    ),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: screenWidth > 600 ? 12 : 10,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Text(
                      quantity.toString(),
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 11 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => addItemToCart(product),
                child: Container(
                  width: buttonHeight,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(5),
                      bottomRight: Radius.circular(5),
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: screenWidth > 600 ? 12 : 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }
}