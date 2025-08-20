import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';

class SellerService {
  static const String _baseUrl = 'https://backend-ecommerce-app-co1r.onrender.com/api';

  // Add timeout duration
  static const Duration _timeout = Duration(seconds: 30);

  /// Submit seller request to become a seller
  static Future<SellerResult> submitSellerRequest(Map<String, String> sellerData) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SellerResult(
          success: false,
          message: 'Authentication required. Please login first.',
        );
      }

      // FIXED: Use the correct endpoint that matches your server
      print('Making request to: $_baseUrl/auth/become-seller');
      print('Request data: ${jsonEncode(sellerData)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/become-seller'),  // FIXED: Correct endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'storeName': sellerData['storeName'],
          'storeAddress': sellerData['storeAddress'],
          'businessLicense': sellerData['businessLicense'],
          // Note: Your server doesn't use panNumber, so removing it
        }),
      ).timeout(_timeout);

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Raw response body: ${response.body}');

      // Check if response is empty
      if (response.body.isEmpty) {
        return SellerResult(
          success: false,
          message: 'Server returned empty response',
        );
      }

      // Check if response starts with HTML (common error page indicator)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        return SellerResult(
          success: false,
          message: 'Server error: Received HTML instead of JSON. Please try again later.',
        );
      }

      // Try to parse JSON with better error handling
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        print('JSON parsing error: $e');
        print('Response body that failed to parse: ${response.body}');
        return SellerResult(
          success: false,
          message: 'Invalid response format from server. Please try again.',
        );
      }

      if (response.statusCode == 200 && data['success'] == true) {
        return SellerResult(
          success: true,
          message: data['message'] ?? 'Seller request submitted successfully',
          requestId: data['request']?['id'],
          requestStatus: data['request']?['status'],
        );
      } else {
        return SellerResult(
          success: false,
          message: data['message'] ?? 'Failed to submit seller request',
        );
      }
    } on http.ClientException catch (e) {
      print('Network error: $e');
      return SellerResult(
        success: false,
        message: 'Network connection error. Please check your internet connection.',
      );
    } on FormatException catch (e) {
      print('Format error: $e');
      return SellerResult(
        success: false,
        message: 'Invalid response from server. Please try again.',
      );
    } catch (e) {
      print('Unexpected error: $e');
      return SellerResult(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  /// Get current user info (includes seller request status)
  static Future<SellerResult> getCurrentUserInfo() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SellerResult(
          success: false,
          message: 'Authentication required',
        );
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),  // FIXED: Use existing endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      return _handleResponse(response, 'User info retrieved');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Check if current user can become a seller
  static Future<SellerResult> checkEligibility() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return SellerResult(
          success: false,
          message: 'Please login first',
        );
      }

      // Check if user is already a seller
      if (currentUser.userType == UserType.seller) {
        return SellerResult(
          success: false,
          message: 'You are already a seller',
        );
      }

      // Check if user has a pending request
      if (currentUser.sellerRequestStatus == SellerRequestStatus.pending) {
        return SellerResult(
          success: false,
          message: 'You already have a pending seller request',
        );
      }

      // Check if user's previous request was rejected
      if (currentUser.sellerRequestStatus == SellerRequestStatus.rejected) {
        return SellerResult(
          success: true,
          message: 'You can reapply to become a seller',
          canReapply: true,
        );
      }

      return SellerResult(
        success: true,
        message: 'You are eligible to become a seller',
      );
    } catch (e) {
      return SellerResult(
        success: false,
        message: 'Error checking eligibility: ${e.toString()}',
      );
    }
  }

  /// Get seller items (for approved sellers)
  static Future<SellerResult> getSellerItems() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SellerResult(
          success: false,
          message: 'Authentication required',
        );
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/items/my-items'),  // FIXED: Use correct endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      return _handleResponse(response, 'Items retrieved successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Add new item (for approved sellers)
  static Future<SellerResult> addItem(Map<String, dynamic> itemData) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SellerResult(
          success: false,
          message: 'Authentication required',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/items'),  // FIXED: Use correct endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(itemData),
      ).timeout(_timeout);

      return _handleResponse(response, 'Item added successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update item (for approved sellers)
  static Future<SellerResult> updateItem(String itemId, Map<String, dynamic> itemData) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SellerResult(
          success: false,
          message: 'Authentication required',
        );
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/items/$itemId'),  // FIXED: Use correct endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(itemData),
      ).timeout(_timeout);

      return _handleResponse(response, 'Item updated successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Delete item (for approved sellers)
  static Future<SellerResult> deleteItem(String itemId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return SellerResult(
          success: false,
          message: 'Authentication required',
        );
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/items/$itemId'),  // FIXED: Use correct endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      return _handleResponse(response, 'Item deleted successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Helper method to handle HTTP responses consistently
  static Future<SellerResult> _handleResponse(http.Response response, String successMessage) async {
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    // Check if response is empty
    if (response.body.isEmpty) {
      return SellerResult(
        success: false,
        message: 'Server returned empty response',
      );
    }

    // Check if response is HTML (error page)
    if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
        response.body.trim().toLowerCase().startsWith('<html')) {
      return SellerResult(
        success: false,
        message: 'Server error occurred. Please try again later.',
      );
    }

    // Try to parse JSON
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      print('JSON parsing error: $e');
      return SellerResult(
        success: false,
        message: 'Invalid response format from server',
      );
    }

    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      UserModel? user;
      if (data['user'] != null) {
        try {
          user = UserModel.fromJson(data['user']);
          await _updateLocalUserData(user);
        } catch (e) {
          print('Error parsing user data: $e');
        }
      }

      return SellerResult(
        success: true,
        message: data['message'] ?? successMessage,
        user: user,
        requestStatus: data['request']?['status'] ?? data['requestStatus'],
        requestId: data['request']?['id'],
        items: data['items'],
        item: data['item'],
      );
    } else {
      return SellerResult(
        success: false,
        message: data['message'] ?? 'Operation failed',
      );
    }
  }

  /// Helper method to handle errors consistently
  static SellerResult _handleError(dynamic error) {
    print('Error occurred: $error');

    if (error is http.ClientException) {
      return SellerResult(
        success: false,
        message: 'Network connection error. Please check your internet connection.',
      );
    } else if (error is FormatException) {
      return SellerResult(
        success: false,
        message: 'Invalid response from server. Please try again.',
      );
    } else {
      return SellerResult(
        success: false,
        message: 'An error occurred: ${error.toString()}',
      );
    }
  }

  /// Update local user data in SharedPreferences
  static Future<void> _updateLocalUserData(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user.toJson()));
    } catch (e) {
      print('Error updating local user data: $e');
    }
  }
}

class SellerResult {
  final bool success;
  final String message;
  final UserModel? user;
  final String? requestStatus;
  final String? requestId;
  final List<dynamic>? items;
  final Map<String, dynamic>? item;
  final bool? canReapply;

  const SellerResult({
    required this.success,
    required this.message,
    this.user,
    this.requestStatus,
    this.requestId,
    this.items,
    this.item,
    this.canReapply,
  });

  @override
  String toString() {
    return 'SellerResult(success: $success, message: $message, user: $user)';
  }
}