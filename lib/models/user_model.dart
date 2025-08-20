// user_model.dart
enum UserType { buyer, seller, admin }

enum SellerRequestStatus {
  none,        // User hasn't requested to become seller
  pending,     // Request submitted, waiting for admin approval
  approved,    // Request approved, user is now a seller
  rejected     // Request rejected by admin
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserType userType;
  final String? profileImage;
  final DateTime? createdAt;

  // Seller request related fields
  final SellerRequestStatus sellerRequestStatus;
  final String? storeName;
  final String? storeAddress;
  final String? panNumber;
  final String? businessLicense;
  final DateTime? sellerRequestDate;
  final DateTime? sellerApprovalDate;
  final String? adminNote;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.userType,
    this.profileImage,
    this.createdAt,
    this.sellerRequestStatus = SellerRequestStatus.none,
    this.storeName,
    this.storeAddress,
    this.panNumber,
    this.businessLicense,
    this.sellerRequestDate,
    this.sellerApprovalDate,
    this.adminNote,
  });

  // Helper methods
  bool get isSellerRequestPending => sellerRequestStatus == SellerRequestStatus.pending;
  bool get isSellerRequestApproved => sellerRequestStatus == SellerRequestStatus.approved;
  bool get isSellerRequestRejected => sellerRequestStatus == SellerRequestStatus.rejected;
  bool get hasRequestedToBecomeSeller => sellerRequestStatus != SellerRequestStatus.none;
  bool get isSeller => userType == UserType.seller;
  bool get isAdmin => userType == UserType.admin; // Added helper method

  // Helper method to parse UserType from string
  static UserType _parseUserType(String? userTypeString) {
    if (userTypeString == null) return UserType.buyer;

    // Handle both "admin" and "UserType.admin" formats
    String cleanType = userTypeString.toLowerCase();
    if (cleanType.contains('admin')) return UserType.admin;
    if (cleanType.contains('seller')) return UserType.seller;
    if (cleanType.contains('buyer')) return UserType.buyer;

    // Fallback: try exact enum match
    try {
      return UserType.values.firstWhere(
            (type) => type.toString() == userTypeString,
        orElse: () => UserType.buyer,
      );
    } catch (e) {
      return UserType.buyer;
    }
  }

  // Helper method to parse SellerRequestStatus from string
  static SellerRequestStatus _parseSellerRequestStatus(String? statusString) {
    if (statusString == null) return SellerRequestStatus.none;

    // Handle both "pending" and "SellerRequestStatus.pending" formats
    String cleanStatus = statusString.toLowerCase();
    if (cleanStatus.contains('pending')) return SellerRequestStatus.pending;
    if (cleanStatus.contains('approved')) return SellerRequestStatus.approved;
    if (cleanStatus.contains('rejected')) return SellerRequestStatus.rejected;
    if (cleanStatus.contains('none')) return SellerRequestStatus.none;

    // Fallback: try exact enum match
    try {
      return SellerRequestStatus.values.firstWhere(
            (status) => status.toString() == statusString,
        orElse: () => SellerRequestStatus.none,
      );
    } catch (e) {
      return SellerRequestStatus.none;
    }
  }

  // Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType.toString(),
      'profileImage': profileImage,
      'createdAt': createdAt?.toIso8601String(),
      'sellerRequestStatus': sellerRequestStatus.toString(),
      'storeName': storeName,
      'storeAddress': storeAddress,
      'panNumber': panNumber,
      'businessLicense': businessLicense,
      'sellerRequestDate': sellerRequestDate?.toIso8601String(),
      'sellerApprovalDate': sellerApprovalDate?.toIso8601String(),
      'adminNote': adminNote,
    };
  }

  // Create UserModel from JSON - FIXED VERSION
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      userType: _parseUserType(json['userType']), // Using helper method
      profileImage: json['profileImage'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      sellerRequestStatus: _parseSellerRequestStatus(json['sellerRequestStatus']), // Using helper method
      storeName: json['storeName'],
      storeAddress: json['storeAddress'],
      panNumber: json['panNumber'],
      businessLicense: json['businessLicense'],
      sellerRequestDate: json['sellerRequestDate'] != null
          ? DateTime.parse(json['sellerRequestDate'])
          : null,
      sellerApprovalDate: json['sellerApprovalDate'] != null
          ? DateTime.parse(json['sellerApprovalDate'])
          : null,
      adminNote: json['adminNote'],
    );
  }

  // Copy UserModel with updated fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserType? userType,
    String? profileImage,
    DateTime? createdAt,
    SellerRequestStatus? sellerRequestStatus,
    String? storeName,
    String? storeAddress,
    String? panNumber,
    String? businessLicense,
    DateTime? sellerRequestDate,
    DateTime? sellerApprovalDate,
    String? adminNote,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      sellerRequestStatus: sellerRequestStatus ?? this.sellerRequestStatus,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      panNumber: panNumber ?? this.panNumber,
      businessLicense: businessLicense ?? this.businessLicense,
      sellerRequestDate: sellerRequestDate ?? this.sellerRequestDate,
      sellerApprovalDate: sellerApprovalDate ?? this.sellerApprovalDate,
      adminNote: adminNote ?? this.adminNote,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, phone: $phone, userType: $userType, sellerRequestStatus: $sellerRequestStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}