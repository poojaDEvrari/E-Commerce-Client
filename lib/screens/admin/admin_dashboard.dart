import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';

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

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final int stock;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.stock,
    required this.isActive,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      stock: json['stock'] ?? 0,
      isActive: json['isActive'] ?? json['isAvailable'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
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

  int _totalUsers = 0;
  int _totalProducts = 0;
  int _activeProducts = 0;
  int _inactiveProducts = 0;

  // Users
  List<User> _users = [];
  String _userSearchQuery = '';

  // Products
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _productSearchQuery = '';

  // Controllers
  late TextEditingController _userSearchController;
  late TextEditingController _productSearchController;

  // Tab controller
  late TabController _tabController;

  // Loading states
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userSearchController = TextEditingController();
    _productSearchController = TextEditingController();

    _userSearchController.addListener(() {
      setState(() {
        _userSearchQuery = _userSearchController.text;
      });
      _fetchUsers();
    });

    _productSearchController.addListener(() {
      setState(() {
        _productSearchQuery = _productSearchController.text;
      });
      _filterProducts();
    });

    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUsers(),
      _fetchProducts(),
    ]);
    setState(() => _isLoading = false);
  }

  void _calculateStats() {
    _totalUsers = _users.length;
    _totalProducts = _products.length;
    _activeProducts = _products.where((p) => p.isActive).length;
    _inactiveProducts = _products.where((p) => !p.isActive).length;
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

  Future<void> _fetchProducts() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/items?limit=1000'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final itemsList = data['items'] ?? data['products'] ?? data['data'] ?? [];
        setState(() {
          _products = itemsList
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _filterProducts();
        _calculateStats();
      }
    } catch (e) {
      print('Error fetching products: $e');
    }
  }

  void _filterProducts() {
    setState(() {
      if (_productSearchQuery.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products
            .where((product) =>
                product.name.toLowerCase().contains(_productSearchQuery.toLowerCase()) ||
                product.category.toLowerCase().contains(_productSearchQuery.toLowerCase()))
            .toList();
      }
    });
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

  Future<void> _toggleProductStatus(String productId, bool isActive) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/items/$productId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isAvailable': isActive}),
      );
      if (res.statusCode == 200) {
        await _fetchProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Product ${isActive ? 'activated' : 'deactivated'} successfully')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update product status')),
      );
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/items/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        await _fetchProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete product')),
      );
    }
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    final stockController = TextEditingController();
    final imageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23293A),
          title: const Text(
            'Add New Product',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nameController, 'Product Name'),
                const SizedBox(height: 12),
                _buildDialogTextField(descriptionController, 'Description'),
                const SizedBox(height: 12),
                _buildDialogTextField(priceController, 'Price', isNumber: true),
                const SizedBox(height: 12),
                _buildDialogTextField(categoryController, 'Category'),
                const SizedBox(height: 12),
                _buildDialogTextField(stockController, 'Stock', isNumber: true),
                const SizedBox(height: 12),
                _buildDialogTextField(imageController, 'Image URL'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  await _addProduct({
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'price': double.tryParse(priceController.text) ?? 0,
                    'category': categoryController.text,
                    'stock': int.tryParse(stockController.text) ?? 0,
                    'images': imageController.text.isNotEmpty 
                        ? [imageController.text] 
                        : [],
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Product'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF151A24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _addProduct(Map<String, dynamic> productData) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A24),
        elevation: 0,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Users"),
            Tab(text: "Products"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildProductsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Dashboard Overview",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildStatCard(
                  "Total Users",
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  "Total Products",
                  _totalProducts.toString(),
                  Icons.inventory,
                  Colors.green,
                ),
                _buildStatCard(
                  "Active Products",
                  _activeProducts.toString(),
                  Icons.check_circle,
                  Colors.orange,
                ),
                _buildStatCard(
                  "Inactive Products",
                  _inactiveProducts.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF23293A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
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
                  ))
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
                        backgroundColor: user.isActive ? Colors.green : Colors.red,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Products",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text("Add Product"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _productSearchBar(),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                    "No products found.",
                    style: TextStyle(color: Colors.grey),
                  ))
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

  Widget _productSearchBar() {
    return TextField(
      controller: _productSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search products...',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF151A24),
                  ),
                  child: product.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.inventory,
                          color: Colors.grey,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.category,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${product.price.toStringAsFixed(2)} • Stock: ${product.stock}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: product.isActive,
                      onChanged: (value) => _toggleProductStatus(product.id, value),
                      activeColor: Colors.green,
                    ),
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(product),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
            if (product.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                product.description,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23293A),
          title: const Text(
            'Delete Product',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProduct(product.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
