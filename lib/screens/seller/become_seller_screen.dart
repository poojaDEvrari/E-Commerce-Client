import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/seller_service.dart'; 

class BecameSellerScreen extends StatefulWidget {
  const BecameSellerScreen({super.key});

  @override
  State<BecameSellerScreen> createState() => _BecameSellerScreenState();
}

class _BecameSellerScreenState extends State<BecameSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _panNumberController = TextEditingController();
  final _businessLicenseController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _panNumberController.dispose();
    _businessLicenseController.dispose();
    super.dispose();
  }

  /// Check if user is eligible to become a seller
  Future<void> _checkEligibility() async {
    final result = await SellerService.checkEligibility();
    if (!result.success && mounted) {
      _showSnackBar(result.message, isError: true);
      // Optionally navigate back if not eligible
      if (!result.success && result.canReapply != true) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final sellerData = {
        'storeName': _storeNameController.text.trim(),
        'storeAddress': _storeAddressController.text.trim(),
        'panNumber': _panNumberController.text.trim(),
        'businessLicense': _businessLicenseController.text.trim(),
      };

      final result = await SellerService.submitSellerRequest(sellerData);

      if (!mounted) return;

      if (result.success) {
        _showSuccessDialog();
      } else {
        _showSnackBar(result.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to submit request. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Request Submitted!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Your seller request has been submitted successfully. You will be notified once it\'s reviewed by our team.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'OK',
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Become a Seller',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeaderSection(),

                const SizedBox(height: 32),

                // Form Fields
                _buildForm(),

                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: 'Submit Request',
                  onPressed: _handleSubmit,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.store,
            size: 40,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Start Your Journey',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Fill out the form below to become a seller on our platform',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Store Name Field
        CustomTextField(
          controller: _storeNameController,
          label: 'Store Name',
          hint: 'Enter your store name',
          prefixIcon: Icons.store_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your store name';
            }
            if (value.length < 3) {
              return 'Store name must be at least 3 characters';
            }
            return null;
          },
        ),

        const SizedBox(height: 20),

        // Store Address Field
        CustomTextField(
          controller: _storeAddressController,
          label: 'Store Address',
          hint: 'Enter your complete store address',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your store address';
            }
            if (value.length < 10) {
              return 'Please enter a complete address';
            }
            return null;
          },
        ),

        const SizedBox(height: 20),

        // PAN Number Field
        CustomTextField(
          controller: _panNumberController,
          label: 'PAN Number',
          hint: 'Enter your PAN number',
          prefixIcon: Icons.credit_card_outlined,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your PAN number';
            }
            // Basic PAN validation (10 characters, alphanumeric)
            if (value.length != 10) {
              return 'PAN number must be 10 characters';
            }
            if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value)) {
              return 'Please enter a valid PAN number';
            }
            return null;
          },
        ),

        const SizedBox(height: 20),

        // Business License Number Field (Optional)
        CustomTextField(
          controller: _businessLicenseController,
          label: 'Business License Number (Optional)',
          hint: 'Enter your business license number',
          prefixIcon: Icons.business_outlined,
          validator: (value) {
            // Optional field, no validation required
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Info Text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your request will be reviewed by our team. You will be notified once approved.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}