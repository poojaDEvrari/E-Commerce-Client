//product_model.dart
class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final int stock;
  final String sellerId;
  final String sellerName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.stock,
    required this.sellerId,
    required this.sellerName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  // Convert ProductModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'stock': stock,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create ProductModel from JSON
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      stock: json['stock'] ?? 0,
      sellerId: json['sellerId'] ?? '',
      sellerName: json['sellerName'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  // Copy ProductModel with updated fields
  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? images,
    int? stock,
    String? sellerId,
    String? sellerName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, price: $price, stock: $stock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Cart Item Model
class CartItem {
  final String productId;
  final String productName;
  final double price;
  final String image;
  final int quantity;
  final String sellerId;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.image,
    required this.quantity,
    required this.sellerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'image': image,
      'quantity': quantity,
      'sellerId': sellerId,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      image: json['image'] ?? '',
      quantity: json['quantity'] ?? 0,
      sellerId: json['sellerId'] ?? '',
    );
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    double? price,
    String? image,
    int? quantity,
    String? sellerId,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
      sellerId: sellerId ?? this.sellerId,
    );
  }

  double get totalPrice => price * quantity;
}