import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import 'order_invoice_generator.dart';

// ----------- MODELS -----------

class SellerRequest {
  final String id;
  final String userName;
  final String userEmail;
  final String storeName;
  final String storeAddress;
  final String? businessLicense;
  final String status;
  final DateTime requestedAt;

  SellerRequest({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.storeName,
    required this.storeAddress,
    this.businessLicense,
    required this.status,
    required this.requestedAt,
  });

  factory SellerRequest.fromJson(Map<String, dynamic> json) {
    return SellerRequest(
      id: json['_id'] ?? '',
      userName: json['userName'] ?? json['userId']?['name'] ?? '',
      userEmail: json['userEmail'] ?? json['userId']?['email'] ?? '',
      storeName: json['storeName'] ?? '',
      storeAddress: json['storeAddress'] ?? '',
      businessLicense: json['businessLicense'],
      status: json['status'] ?? 'pending',
      requestedAt:
          DateTime.tryParse(json['requestedAt'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
    );
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class Seller {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String storeName;
  final String storeAddress;
  final bool isActive;
  final DateTime createdAt;

  Seller({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.storeName,
    required this.storeAddress,
    required this.isActive,
    required this.createdAt,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: json['_id'] ?? '',
      name: json['name'] ?? json['userId']?['name'] ?? '',
      email: json['email'] ?? json['userId']?['email'] ?? '',
      phone: json['phone'] ?? json['userId']?['phone'] ?? '',
      storeName: json['storeName'] ?? '',
      storeAddress: json['storeAddress'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final String sellerId;
  final String? sellerName;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    required this.isAvailable,
    required this.sellerId,
    this.sellerName,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? json['images']?[0],
      isAvailable: json['isAvailable'] ?? true,
      sellerId: json['sellerId'] ?? json['seller']?['_id'] ?? '',
      sellerName: json['seller']?['storeName'] ?? json['sellerName'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    String? sellerId,
    String? sellerName,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ----------- MAIN DASHBOARD WIDGET -----------

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  // API BASE URL
  static const String _baseUrl =
      "https://backend-ecommerce-app-co1r.onrender.com/api";

  // Dashboard stats
  int _totalUsers = 0;
  int _totalSellers = 0;
  int _totalProducts = 0;
  int _availableProducts = 0;
  int _hiddenProducts = 0;

  // Seller Requests
  List<SellerRequest> _pendingRequests = [];

  // Users
  List<User> _users = [];
  String _userSearchQuery = '';

  // Sellers
  List<Seller> _sellers = [];
  String _sellerSearchQuery = '';

  // Products
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _productSearchQuery = '';
  String _productFilter = 'all';

  // Orders
  List<Orders> _orders = [];
  List<Order> _order = [];
  List<Orders> _filteredOrders = [];
  String _orderSearchQuery = '';
  String _orderFilter = 'all';
  bool _isLoadingOrders = false;

  // Product Management
  bool _isAddingProduct = false;
  final _productFormKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productQuantityController = TextEditingController();
  String _selectedProductCategory = 'Fruits';
  String _selectedProductUnit = 'kg';
  String? _selectedProductImageUrl;
  String? _selectedPredefinedItem;
  bool _isEditProductMode = false;
  String? _editingProductId;

  // UI State
  bool _isLoading = true;
  int _tabIndex = 0;
  bool _isSidebarExpanded = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _sellerSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _orderSearchController = TextEditingController();

  // --- INIT ---
  @override
  void initState() {
    super.initState();
    _loadAllData();
    _userSearchController.addListener(() {
      setState(() {
        _userSearchQuery = _userSearchController.text;
        _fetchUsers();
      });
    });
    _sellerSearchController.addListener(() {
      setState(() {
        _sellerSearchQuery = _sellerSearchController.text;
        _fetchSellers();
      });
    });

    _productSearchController.addListener(() {
      setState(() {
        _productSearchQuery = _productSearchController.text;
        _filterProducts();
      });
    });

    _orderSearchController.addListener(() {
      setState(() {
        _orderSearchQuery = _orderSearchController.text;
        _filterOrders();
      });
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productQuantityController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // --- FIXED API CALLS ---

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProducts(), // Fetch products first to calculate stats
      _fetchSellerRequests(),
      _fetchUsers(),
      _fetchSellers(),
      _fetchOrders(), // Fetch orders for the new tab
    ]);
    setState(() => _isLoading = false);
  }

  // FIXED: Calculate stats from actual data instead of separate API call
  void _calculateStats() {
    setState(() {
      _totalProducts = _products.length;
      _availableProducts = _products.where((p) => p.isAvailable).length;
      _hiddenProducts = _products.where((p) => !p.isAvailable).length;
      _totalUsers = _users.length;
      _totalSellers = _sellers.length;
    });
  }

  Future<void> _fetchSellerRequests() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/seller-requests?status=pending&limit=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _pendingRequests = (data['requests'] as List)
              .map((e) => SellerRequest.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching seller requests: $e');
    }
  }

  Future<void> _fetchUsers() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      String url = '$_baseUrl/admin/users?limit=100';
      if (_userSearchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_userSearchQuery)}';
      }
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _users = (data['users'] as List)
              .map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _calculateStats();
      }
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  Future<void> _fetchSellers() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      String url = '$_baseUrl/admin/sellers?limit=100';
      if (_sellerSearchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_sellerSearchQuery)}';
      }
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _sellers = (data['sellers'] as List)
              .map((e) => Seller.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _calculateStats();
      }
    } catch (e) {
      print('Error fetching sellers: $e');
    }
  }

  // FIXED: Use correct API endpoint and better error handling
  Future<void> _fetchProducts() async {
    final token = await _getToken();
    if (token == null) {
      print('No auth token found');
      return;
    }

    try {
      print('Fetching products from API...');

      // Use the correct endpoint from your API documentation
      final res = await http.get(
        Uri.parse('$_baseUrl/items?limit=1000'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Products API Response Status: ${res.statusCode}');
      print('Products API Response Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Handle different possible response structures
        List<dynamic> itemsList = [];
        if (data is Map<String, dynamic>) {
          itemsList = data['items'] ?? data['products'] ?? data['data'] ?? [];
        } else if (data is List) {
          itemsList = data;
        }

        print('Found ${itemsList.length} products');

        setState(() {
          _products = itemsList
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();

          print('Parsed ${_products.length} products successfully');

          // Calculate stats immediately after fetching
          _totalProducts = _products.length;
          _availableProducts = _products.where((p) => p.isAvailable).length;
          _hiddenProducts = _products.where((p) => !p.isAvailable).length;

          print(
              'Stats - Total: $_totalProducts, Available: $_availableProducts, Hidden: $_hiddenProducts');

          _filterProducts();
        });
      } else if (res.statusCode == 401) {
        print('Unauthorized - token may be invalid');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print('Failed to fetch products: ${res.statusCode} - ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: ${res.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error fetching products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _products.where((product) {
        bool matchesSearch = _productSearchQuery.isEmpty ||
            product.name
                .toLowerCase()
                .contains(_productSearchQuery.toLowerCase()) ||
            product.category
                .toLowerCase()
                .contains(_productSearchQuery.toLowerCase()) ||
            (product.sellerName
                    ?.toLowerCase()
                    .contains(_productSearchQuery.toLowerCase()) ??
                false);

        bool matchesFilter = _productFilter == 'all' ||
            (_productFilter == 'available' && product.isAvailable) ||
            (_productFilter == 'hidden' && !product.isAvailable);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  // --- ORDER METHODS ---

  Future<void> _fetchOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      // Try to fetch from API first
      final orders = await AdminService.getAllOrders();
      setState(() {
        _order = orders;
        _filterOrders();
      });
    } catch (e) {
      // If API fails, use dummy data for testing
      print('API failed,');
    } finally {
      setState(() => _isLoadingOrders = false);
    }
  }

  // Dummy data for testing

  void _filterOrders() {
    setState(() {
      _filteredOrders = _orders.where((order) {
        bool matchesSearch = _orderSearchQuery.isEmpty ||
            order.userName
                .toLowerCase()
                .contains(_orderSearchQuery.toLowerCase()) ||
            order.userEmail
                .toLowerCase()
                .contains(_orderSearchQuery.toLowerCase()) ||
            order.id.toLowerCase().contains(_orderSearchQuery.toLowerCase());

        bool matchesFilter = _orderFilter == 'all' ||
            (_orderFilter == 'pending' && order.status == 'pending') ||
            (_orderFilter == 'completed' && order.status == 'completed') ||
            (_orderFilter == 'cancelled' && order.status == 'cancelled');

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  Future<void> _downloadInvoice(String orderId) async {
    try {
      // Find the order by ID
      final order = _orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => throw Exception('Order not found'),
      );

      // Generate and download invoice using the OrderInvoiceGenerator
      await OrderInvoiceGenerator.generateAndDownloadInvoice(context, order);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download invoice: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewUserDetails(String userId) async {
    try {
      // Try to fetch from API first
      final userDetails = await AdminService.getUserDetails(userId);
      final userOrders = await AdminService.getUserOrderHistory(userId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _UserDetailsDialog(
            userDetails: userDetails,
            orders: userOrders,
          ),
        );
      }
    } catch (e) {
      // If API fails, use dummy data for testing
      print('API failed');
    }
  }

  // Dummy user details for testing

  Future<void> _approveSellerRequest(String requestId) async {
    final token = await _getToken();
    if (token == null) return;
    final res = await http.post(
      Uri.parse('$_baseUrl/admin/seller-requests/$requestId/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) {
      await _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller request approved')),
      );
    }
  }

  Future<void> _rejectSellerRequest(String requestId, String reason) async {
    final token = await _getToken();
    if (token == null) return;
    final res = await http.post(
      Uri.parse('$_baseUrl/admin/seller-requests/$requestId/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode == 200) {
      await _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller request rejected')),
      );
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/users/$userId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isActive': isActive}),
      );
      if (res.statusCode == 200) {
        await _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'User ${isActive ? 'activated' : 'deactivated'} successfully')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update user status')),
      );
    }
  }

  Future<void> _toggleSellerStatus(String sellerId, bool isActive) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/sellers/$sellerId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isActive': isActive}),
      );
      if (res.statusCode == 200) {
        await _fetchSellers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Seller ${isActive ? 'activated' : 'deactivated'} successfully')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update seller status')),
      );
    }
  }

  // FIXED: Use correct API endpoint for toggling product availability
  Future<void> _toggleProductAvailability(
      String productId, bool isAvailable) async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication token not found')),
      );
      return;
    }

    try {
      print(
          'Toggling product $productId to ${isAvailable ? 'available' : 'unavailable'}');

      // Use the correct endpoint from your backend API
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/items/$productId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isAvailable': isAvailable}),
      );

      print('Toggle response status: ${res.statusCode}');
      print('Toggle response body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Update the product in the local list immediately
          setState(() {
            final productIndex = _products.indexWhere((p) => p.id == productId);
            if (productIndex != -1) {
              _products[productIndex] =
                  _products[productIndex].copyWith(isAvailable: isAvailable);

              // Recalculate stats
              _availableProducts = _products.where((p) => p.isAvailable).length;
              _hiddenProducts = _products.where((p) => !p.isAvailable).length;

              // Reapply filters
              _filterProducts();
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  data['message'] ?? 'Product status updated successfully'),
              backgroundColor: isAvailable ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to update product status');
        }
      } else {
        throw Exception(
            'API request failed with status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('Error in _toggleProductAvailability: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product status: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // --- PRODUCT MANAGEMENT METHODS ---

  Future<void> _addProduct() async {
    if (!_productFormKey.currentState!.validate()) return;

    setState(() => _isAddingProduct = true);

    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      String? imageUrl = _selectedProductImageUrl;

      if (_selectedPredefinedItem != null) {
        // Get image URL from predefined items
        imageUrl = _getPredefinedItemImageUrl(_selectedPredefinedItem!);
      }

      final productData = {
        'name': _productNameController.text,
        'description': _productDescriptionController.text,
        'price': double.parse(_productPriceController.text),
        'category': _selectedProductCategory,
        'imageUrl': imageUrl,
        'quantity': int.parse(_productQuantityController.text),
        'unit': _selectedProductUnit,
        'isAvailable': true,
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );

      final data = jsonDecode(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) &&
          data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Product added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearProductForm();
        await _fetchProducts(); // Refresh products list
        setState(() => _tabIndex = 4); // Switch to products tab
      } else {
        throw Exception(data['message'] ??
            'Failed to add product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error adding product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isAddingProduct = false);
    }
  }

  Future<void> _updateProduct() async {
    if (!_productFormKey.currentState!.validate() || _editingProductId == null)
      return;

    setState(() => _isAddingProduct = true);

    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      String? imageUrl = _selectedProductImageUrl;

      if (_selectedPredefinedItem != null) {
        imageUrl = _getPredefinedItemImageUrl(_selectedPredefinedItem!);
      }

      final productData = {
        'name': _productNameController.text,
        'description': _productDescriptionController.text,
        'price': double.parse(_productPriceController.text),
        'category': _selectedProductCategory,
        'imageUrl': imageUrl,
        'quantity': int.parse(_productQuantityController.text),
        'unit': _selectedProductUnit,
      };

      final res = await http.put(
        Uri.parse('$_baseUrl/items/$_editingProductId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Product updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearProductForm();
        await _fetchProducts(); // Refresh products list
        setState(() => _tabIndex = 4); // Switch to products tab
      } else {
        throw Exception(data['message'] ??
            'Failed to update product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isAddingProduct = false);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      final res = await http.delete(
        Uri.parse('$_baseUrl/items/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Product deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchProducts(); // Refresh products list
      } else {
        throw Exception(data['message'] ??
            'Failed to delete product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editProduct(Product product) {
    _productNameController.text = product.name;
    _productDescriptionController.text = product.description;
    _productPriceController.text = product.price.toString();
    _productQuantityController.text = '1'; // Default quantity
    _selectedProductCategory = product.category;
    _selectedProductUnit = 'kg'; // Default unit
    _selectedProductImageUrl = product.imageUrl;
    _selectedPredefinedItem = null;

    setState(() {
      _isEditProductMode = true;
      _editingProductId = product.id;
      _tabIndex = 6; // Switch to add product tab
    });
  }

  void _clearProductForm() {
    _productNameController.clear();
    _productDescriptionController.clear();
    _productPriceController.clear();
    _productQuantityController.clear();
    _selectedProductCategory = 'Fruits';
    _selectedProductUnit = 'kg';
    _selectedProductImageUrl = null;
    _selectedPredefinedItem = null;
    _isEditProductMode = false;
    _editingProductId = null;
  }

  String _getPredefinedItemImageUrl(String itemName) {
    // Map predefined items to image URLs
    final predefinedImages = {
      'Apple':
          'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400',
      'Banana':
          'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400',
      'Orange':
          'https://images.unsplash.com/photo-1547514701-42782101795e?w=400',
      'Milk': 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400',
      'Bread':
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
      'Eggs':
          'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400',
      'Chicken':
          'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400',
      'Rice':
          'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400',
    };
    return predefinedImages[itemName] ?? '';
  }

  void _showDeleteProductConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23293A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Product',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${product.name}"?',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProduct(product.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILD (keeping the same UI code) ---

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF151A24),
        cardColor: const Color(0xFF23293A),
        dividerColor: Colors.grey[700],
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.greenAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23293A),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        key: _scaffoldKey,
        body: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidebarWidth = constraints.maxWidth < 768
                  ? 60.0
                  : (_isSidebarExpanded ? 250.0 : 70.0);

              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: sidebarWidth,
                    child: _buildSidebar(constraints.maxWidth < 768),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : IndexedStack(
                                  index: _tabIndex,
                                  children: [
                                    _buildOverviewTab(),
                                    _buildRequestsTab(),
                                    _buildSellersTab(),
                                    _buildUsersTab(),
                                    _buildProductsTab(),
                                    _buildOrdersTab(),
                                    _buildAddProductTab(),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF23293A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF151A24), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarExpanded ? Icons.menu_open : Icons.menu,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSidebarExpanded = !_isSidebarExpanded;
              });
            },
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "Admin Dashboard",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Add refresh button for debugging
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadAllData();
            },
            tooltip: "Refresh Data",
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, "/home");
            },
            tooltip: "Go to Home",
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isSmallScreen) {
    final bool showExpanded = !isSmallScreen && _isSidebarExpanded;

    return Container(
      color: const Color(0xFF23293A),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showExpanded) ...[
            const Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blueAccent, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "GroceryAdmin",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ] else ...[
            const Center(
              child:
                  Icon(Icons.shopping_cart, color: Colors.blueAccent, size: 28),
            ),
            const SizedBox(height: 40),
          ],
          _sidebarNavItem(Icons.dashboard, "Dashboard", 0, showExpanded),
          _sidebarNavItem(
              Icons.pending_actions, "Seller Requests", 1, showExpanded),
          _sidebarNavItem(Icons.store, "Sellers", 2, showExpanded),
          _sidebarNavItem(Icons.people, "Users", 3, showExpanded),
          _sidebarNavItem(Icons.inventory, "Products", 4, showExpanded),
          _sidebarNavItem(
              Icons.receipt_long, "Orders & Invoices", 5, showExpanded),
          _sidebarNavItem(
              Icons.add_shopping_cart, "Add Products", 6, showExpanded),
        ],
      ),
    );
  }

  Widget _sidebarNavItem(IconData icon, String text, int index, bool showText) {
    final bool selected = _tabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _tabIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.blueAccent : Colors.grey[400],
            ),
            if (showText) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: selected ? Colors.blueAccent : Colors.grey[300],
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TABS (keeping the same UI code for brevity) ---

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              // Debug info
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Text(
                  'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1200) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("No. of Users",
                                _totalUsers.toString(), Icons.people)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard("No. of Sellers",
                                _totalSellers.toString(), Icons.store_rounded)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard("Total Products",
                                _totalProducts.toString(), Icons.inventory)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                "Available Products",
                                _availableProducts.toString(),
                                Icons.visibility,
                                Colors.green)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard(
                                "Hidden Products",
                                _hiddenProducts.toString(),
                                Icons.visibility_off,
                                Colors.orange)),
                        const SizedBox(width: 20),
                        Expanded(child: Container()),
                      ],
                    ),
                  ],
                );
              } else if (constraints.maxWidth > 900) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("No. of Users",
                                _totalUsers.toString(), Icons.people)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard("No. of Sellers",
                                _totalSellers.toString(), Icons.store_rounded)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("Total Products",
                                _totalProducts.toString(), Icons.inventory)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard(
                                "Available Products",
                                _availableProducts.toString(),
                                Icons.visibility,
                                Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _statCard("Hidden Products", _hiddenProducts.toString(),
                        Icons.visibility_off, Colors.orange),
                  ],
                );
              } else if (constraints.maxWidth > 600) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("No. of Users",
                                _totalUsers.toString(), Icons.people)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard("No. of Sellers",
                                _totalSellers.toString(), Icons.store_rounded)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _statCard("Total Products", _totalProducts.toString(),
                        Icons.inventory),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                "Available",
                                _availableProducts.toString(),
                                Icons.visibility,
                                Colors.green)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard(
                                "Hidden",
                                _hiddenProducts.toString(),
                                Icons.visibility_off,
                                Colors.orange)),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _statCard(
                        "No. of Users", _totalUsers.toString(), Icons.people),
                    const SizedBox(height: 20),
                    _statCard("No. of Sellers", _totalSellers.toString(),
                        Icons.store_rounded),
                    const SizedBox(height: 20),
                    _statCard("Total Products", _totalProducts.toString(),
                        Icons.inventory),
                    const SizedBox(height: 20),
                    _statCard(
                        "Available Products",
                        _availableProducts.toString(),
                        Icons.visibility,
                        Colors.green),
                    const SizedBox(height: 20),
                    _statCard("Hidden Products", _hiddenProducts.toString(),
                        Icons.visibility_off, Colors.orange),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      [Color? iconColor]) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: const Color(0xFF23293A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: iconColor ?? Colors.blueAccent),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- ADD PRODUCT TAB ---
  Widget _buildAddProductTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isEditProductMode ? "Edit Product" : "Add New Product",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                const Spacer(),
                if (_isEditProductMode)
                  TextButton.icon(
                    onPressed: _clearProductForm,
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    label: const Text(
                      "Clear Form",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _productFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    const Text(
                      "Product Name *",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _productNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF151A24),
                        hintText: 'Enter product name',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Product Description
                    const Text(
                      "Description *",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _productDescriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF151A24),
                        hintText: 'Enter product description',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Product description is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Price and Quantity Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Price *",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _productPriceController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF151A24),
                                  hintText: '0.00',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  prefixText: '\$ ',
                                  prefixStyle:
                                      const TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Price is required';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid price';
                                  }
                                  if (double.parse(value) <= 0) {
                                    return 'Price must be greater than 0';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Quantity *",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _productQuantityController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF151A24),
                                  hintText: '1',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Quantity is required';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Please enter a valid quantity';
                                  }
                                  if (int.parse(value) <= 0) {
                                    return 'Quantity must be greater than 0';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Category and Unit Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Category *",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF151A24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedProductCategory,
                                  dropdownColor: const Color(0xFF23293A),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  items: [
                                    'Fruits',
                                    'Vegetables',
                                    'Dairy',
                                    'Bakery',
                                    'Meat',
                                    'Grains',
                                    'Beverages',
                                    'Snacks',
                                    'Household',
                                    'Other'
                                  ].map((String category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(category),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedProductCategory = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Unit *",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF151A24),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedProductUnit,
                                  dropdownColor: const Color(0xFF23293A),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  items: [
                                    'kg',
                                    'g',
                                    'lb',
                                    'oz',
                                    'piece',
                                    'pack',
                                    'bottle',
                                    'box',
                                    'bag',
                                    'unit'
                                  ].map((String unit) {
                                    return DropdownMenuItem<String>(
                                      value: unit,
                                      child: Text(unit),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedProductUnit = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Predefined Items
                    const Text(
                      "Quick Add (Optional)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151A24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedPredefinedItem,
                        dropdownColor: const Color(0xFF23293A),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          hintText: 'Select a predefined item (optional)',
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Custom Item'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Apple',
                            child: Text('Apple'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Banana',
                            child: Text('Banana'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Orange',
                            child: Text('Orange'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Milk',
                            child: Text('Milk'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Bread',
                            child: Text('Bread'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Eggs',
                            child: Text('Eggs'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Chicken',
                            child: Text('Chicken'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'Rice',
                            child: Text('Rice'),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPredefinedItem = newValue;
                            if (newValue != null) {
                              _productNameController.text = newValue;
                              _selectedProductImageUrl =
                                  _getPredefinedItemImageUrl(newValue);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Custom Image URL
                    const Text(
                      "Image URL (Optional)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF151A24),
                        hintText:
                            'Enter image URL or use predefined item above',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedProductImageUrl =
                              value.isEmpty ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAddingProduct
                            ? null
                            : (_isEditProductMode
                                ? _updateProduct
                                : _addProduct),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAddingProduct
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Processing...'),
                                ],
                              )
                            : Text(_isEditProductMode
                                ? 'Update Product'
                                : 'Add Product'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all other UI methods the same...
  Widget _buildRequestsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pending Seller Requests",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _pendingRequests.isEmpty
                ? const Center(
                    child: Text(
                    "No pending seller requests.",
                    style: TextStyle(color: Colors.grey),
                  ))
                : ListView.builder(
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      return _sellerRequestCard(_pendingRequests[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sellerRequestCard(SellerRequest req) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              req.storeName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              'Owner: ${req.userName} (${req.userEmail})',
              style: const TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Address: ${req.storeAddress}',
              style: const TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            if (req.businessLicense != null) ...[
              const SizedBox(height: 4),
              Text(
                'Business License: ${req.businessLicense}',
                style: const TextStyle(color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 400) {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text("Approve"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () => _approveSellerRequest(req.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text("Reject"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => _showRejectDialog(req.id),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Approve"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () => _approveSellerRequest(req.id),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Reject"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => _showRejectDialog(req.id),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(String requestId) async {
    String? reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF23293A),
          title: const Text(
            'Reason for rejection',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter reason',
              hintStyle: TextStyle(color: Colors.grey),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Reject"),
            ),
          ],
        );
      },
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await _rejectSellerRequest(requestId, reason.trim());
    }
  }

  Widget _buildSellersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sellers",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 20),
          _sellerSearchBar(),
          const SizedBox(height: 20),
          Expanded(
            child: _sellers.isEmpty
                ? const Center(
                    child: Text(
                    "No sellers found.",
                    style: TextStyle(color: Colors.grey),
                  ))
                : ListView.builder(
                    itemCount: _sellers.length,
                    itemBuilder: (context, index) {
                      return _sellerCard(_sellers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sellerSearchBar() {
    return TextField(
      controller: _sellerSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search sellers...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _sellerCard(Seller seller) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        seller.isActive ? Colors.green : Colors.red,
                    child: Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seller.storeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${seller.name} (${seller.email})',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          seller.storeAddress,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: seller.isActive,
                    onChanged: (value) => _toggleSellerStatus(seller.id, value),
                    activeColor: Colors.green,
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            seller.isActive ? Colors.green : Colors.red,
                        child: Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          seller.storeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: seller.isActive,
                        onChanged: (value) =>
                            _toggleSellerStatus(seller.id, value),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${seller.name} (${seller.email})',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seller.storeAddress,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Users",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 20),
          _userSearchBar(),
          const SizedBox(height: 20),
          Expanded(
            child: _users.isEmpty
                ? const Center(
                    child: Text(
                      "No users found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      return _userCard(_users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _userSearchBar() {
    return TextField(
      controller: _userSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search users...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _userCard(User user) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: user.isActive ? Colors.green : Colors.red,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.phone,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Role: ${user.role}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: user.isActive,
                    onChanged: (value) => _toggleUserStatus(user.id, value),
                    activeColor: Colors.green,
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            user.isActive ? Colors.green : Colors.red,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: user.isActive,
                        onChanged: (value) => _toggleUserStatus(user.id, value),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.phone,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Role: ${user.role}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Products",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  _clearProductForm();
                  setState(() => _tabIndex = 6);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Product"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Showing ${_filteredProducts.length} of ${_totalProducts}',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _productSearchBar()),
              const SizedBox(width: 16),
              _productFilterDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _filterChip('All', 'all', _totalProducts),
              const SizedBox(width: 8),
              _filterChip(
                  'Available', 'available', _availableProducts, Colors.green),
              const SizedBox(width: 8),
              _filterChip('Hidden', 'hidden', _hiddenProducts, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _productFilter == 'all'
                              ? Icons.inventory_2_outlined
                              : _productFilter == 'available'
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _productFilter == 'all'
                              ? "No products found."
                              : _productFilter == 'available'
                                  ? "No available products found."
                                  : "No hidden products found.",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total products in database: $_totalProducts',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      return _productCard(_filteredProducts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, int count, [Color? color]) {
    final isSelected = _productFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _productFilter = value;
          _filterProducts();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Colors.blueAccent).withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? (color ?? Colors.blueAccent) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? (color ?? Colors.blueAccent) : Colors.grey[300],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _productFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: _productFilter,
        dropdownColor: const Color(0xFF23293A),
        underline: Container(),
        icon: const Icon(Icons.filter_list, color: Colors.grey, size: 20),
        items: [
          DropdownMenuItem(
              value: 'all',
              child: Text('All Products ($_totalProducts)',
                  style: const TextStyle(color: Colors.white))),
          DropdownMenuItem(
              value: 'available',
              child: Text('Available ($_availableProducts)',
                  style: const TextStyle(color: Colors.green))),
          DropdownMenuItem(
              value: 'hidden',
              child: Text('Hidden ($_hiddenProducts)',
                  style: const TextStyle(color: Colors.orange))),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _productFilter = value;
              _filterProducts();
            });
          }
        },
      ),
    );
  }

  Widget _productSearchBar() {
    return TextField(
      controller: _productSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search products by name, category, or seller...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _productCard(Product product) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: product.isAvailable
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[800],
                          ),
                          child: product.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.inventory,
                                        color: Colors.grey[400],
                                        size: 40,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.inventory,
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                        ),
                        if (!product.isAvailable)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.withOpacity(0.7),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.visibility_off,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: TextStyle(
                                    color: product.isAvailable
                                        ? Colors.white
                                        : Colors.grey[400],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: product.isAvailable
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: product.isAvailable
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      product.isAvailable
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      size: 12,
                                      color: product.isAvailable
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.isAvailable
                                          ? 'VISIBLE'
                                          : 'HIDDEN',
                                      style: TextStyle(
                                        color: product.isAvailable
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            style: TextStyle(
                              color: product.isAvailable
                                  ? Colors.grey
                                  : Colors.grey[600],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: product.isAvailable
                                      ? Colors.green
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.category,
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (product.sellerName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Seller: ${product.sellerName}',
                              style: TextStyle(
                                color: product.isAvailable
                                    ? Colors.grey
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        Text(
                          product.isAvailable
                              ? 'Customers can see this'
                              : 'Hidden from customers',
                          style: TextStyle(
                            color: product.isAvailable
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: product.isAvailable,
                          onChanged: (value) =>
                              _toggleProductAvailability(product.id, value),
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.orange,
                          inactiveTrackColor: Colors.orange.withOpacity(0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.isAvailable ? 'VISIBLE' : 'HIDDEN',
                          style: TextStyle(
                            color: product.isAvailable
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _editProduct(product),
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit Product',
                            ),
                            IconButton(
                              onPressed: () =>
                                  _showDeleteProductConfirmation(product),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Product',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[800],
                              ),
                              child: product.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        product.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.inventory,
                                            color: Colors.grey[400],
                                            size: 30,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.inventory,
                                      color: Colors.grey[400],
                                      size: 30,
                                    ),
                            ),
                            if (!product.isAvailable)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.visibility_off,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  color: product.isAvailable
                                      ? Colors.white
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: product.isAvailable
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: product.isAvailable
                                      ? Colors.green
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: product.isAvailable
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    product.isAvailable
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    size: 10,
                                    color: product.isAvailable
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    product.isAvailable ? 'VISIBLE' : 'HIDDEN',
                                    style: TextStyle(
                                      color: product.isAvailable
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: product.isAvailable,
                              onChanged: (value) =>
                                  _toggleProductAvailability(product.id, value),
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.orange,
                              inactiveTrackColor:
                                  Colors.orange.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: product.isAvailable
                            ? Colors.grey
                            : Colors.grey[600],
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.category,
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (product.sellerName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Seller: ${product.sellerName}',
                              style: TextStyle(
                                color: product.isAvailable
                                    ? Colors.grey
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: product.isAvailable
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: product.isAvailable
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            product.isAvailable
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                            color: product.isAvailable
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product.isAvailable
                                  ? 'This product is visible to customers and can be purchased'
                                  : 'This product is hidden from customers and cannot be purchased',
                              style: TextStyle(
                                color: product.isAvailable
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // --- ORDERS TAB ---
  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Orders & Invoices",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Refresh"),
                onPressed: _fetchOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _orderSearchBar()),
              const SizedBox(width: 16),
              _orderFilterDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _orderFilterChip('All', 'all', _orders.length),
              const SizedBox(width: 8),
              _orderFilterChip(
                  'Pending',
                  'pending',
                  _orders.where((o) => o.status == 'pending').length,
                  Colors.orange),
              const SizedBox(width: 8),
              _orderFilterChip(
                  'Completed',
                  'completed',
                  _orders.where((o) => o.status == 'completed').length,
                  Colors.green),
              const SizedBox(width: 8),
              _orderFilterChip(
                  'Cancelled',
                  'cancelled',
                  _orders.where((o) => o.status == 'cancelled').length,
                  Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No orders found.",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total orders: ${_orders.length}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          return _orderCard(_filteredOrders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _orderSearchBar() {
    return TextField(
      controller: _orderSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search orders by customer name, email, or order ID...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _orderFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: _orderFilter,
        dropdownColor: const Color(0xFF23293A),
        underline: Container(),
        icon: const Icon(Icons.filter_list, color: Colors.grey, size: 20),
        items: [
          DropdownMenuItem(
              value: 'all',
              child: Text('All Orders (${_orders.length})',
                  style: const TextStyle(color: Colors.white))),
          DropdownMenuItem(
              value: 'pending',
              child: Text(
                  'Pending (${_orders.where((o) => o.status == 'pending').length})',
                  style: const TextStyle(color: Colors.orange))),
          DropdownMenuItem(
              value: 'completed',
              child: Text(
                  'Completed (${_orders.where((o) => o.status == 'completed').length})',
                  style: const TextStyle(color: Colors.green))),
          DropdownMenuItem(
              value: 'cancelled',
              child: Text(
                  'Cancelled (${_orders.where((o) => o.status == 'cancelled').length})',
                  style: const TextStyle(color: Colors.red))),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _orderFilter = value;
              _filterOrders();
            });
          }
        },
      ),
    );
  }

  Widget _orderFilterChip(String label, String value, int count,
      [Color? color]) {
    final isSelected = _orderFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _orderFilter = value;
          _filterOrders();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Colors.blueAccent).withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? (color ?? Colors.blueAccent) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? (color ?? Colors.blueAccent) : Colors.grey[300],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Orders order) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8)}...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.userName,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        order.userEmail,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(order.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${order.items.length} items • ${order.items.fold(0, (sum, item) => sum + item.quantity)} total quantity',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(order.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text("View Customer"),
                    onPressed: () => _viewUserDetails(order.userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      foregroundColor: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text("Download Invoice"),
                    onPressed: () => _downloadInvoice(order.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// User Details Dialog Widget
class _UserDetailsDialog extends StatelessWidget {
  final UserDetails userDetails;
  final List<Order> orders;

  const _UserDetailsDialog({
    required this.userDetails,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF23293A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      userDetails.isActive ? Colors.green : Colors.red,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDetails.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        userDetails.email,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        userDetails.phone,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // User Stats
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Orders',
                    userDetails.totalOrders.toString(),
                    Icons.shopping_bag,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statCard(
                    'Total Spent',
                    '\$${userDetails.totalSpent.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Order History',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders found for this user.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          color: const Color(0xFF151A24),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order #${order.id.substring(0, 8)}...',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${order.items.length} items',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${order.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(order.status)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        order.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(order.status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
