import 'package:flutter/material.dart';
import 'constants.dart';
import '../../items/items.dart';

class ItemForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final String selectedCategory;
  final String selectedUnit;
  final String? selectedImageUrl;
  final String? selectedPredefinedItem;
  final bool isEditMode;
  final bool isLoading;
  final Function(String) onCategoryChanged;
  final Function(String) onUnitChanged;
  final Function(String?) onPredefinedItemChanged;
  final VoidCallback onSubmit;

  const ItemForm({
    Key? key,
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.quantityController,
    required this.selectedCategory,
    required this.selectedUnit,
    this.selectedImageUrl,
    this.selectedPredefinedItem,
    required this.isEditMode,
    required this.isLoading,
    required this.onCategoryChanged,
    required this.onUnitChanged,
    required this.onPredefinedItemChanged,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            title: isEditMode ? 'Edit Item' : 'Add New Item',
            subtitle: isEditMode ? 'Update your product details' : 'Expand your product catalog',
          ),
          const SizedBox(height: 32),
          Form(
            key: formKey,
            child: Column(
              children: [
                _buildPredefinedImageSelector(context),
                const SizedBox(height: 24),
                _buildFormFields(context),
                const SizedBox(height: 32),
                _buildPublishButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required String subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isCompact ? 28 : 36,
                fontWeight: FontWeight.w800,
                color: AppConstants.textPrimary,
                letterSpacing: -1.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: AppConstants.textSecondary,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPredefinedImageSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppConstants.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Product Image',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selectedPredefinedItem,
            decoration: InputDecoration(
              labelText: 'Select Item',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppConstants.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppConstants.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              filled: true,
              fillColor: AppConstants.backgroundColor,
            ),
            isExpanded: true,
            items: GroceryItems.getAllItems().map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onPredefinedItemChanged,
          ),
          if (selectedPredefinedItem != null && selectedImageUrl != null) ...[
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderLight, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  selectedImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image_not_supported_outlined),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormFields(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppConstants.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Product Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: nameController,
            label: 'Product Name',
            hint: 'Enter product name',
            icon: Icons.inventory_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter product name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: descriptionController,
            label: 'Description',
            hint: 'Enter product description',
            icon: Icons.description_rounded,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter description';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth > 600
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: priceController,
                            label: 'Price (₹)',
                            hint: '0.00',
                            icon: Icons.currency_rupee_rounded,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter price';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter valid price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: quantityController,
                            label: 'Quantity',
                            hint: '0',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter quantity';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter valid quantity';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTextField(
                          controller: priceController,
                          label: 'Price (₹)',
                          hint: '0.00',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: quantityController,
                          label: 'Quantity',
                          hint: '0',
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter quantity';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter valid quantity';
                            }
                            return null;
                          },
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth > 600
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Category',
                            value: selectedCategory,
                            items: AppConstants.categories,
                            icon: Icons.category_rounded,
                            onChanged: (value) => onCategoryChanged(value!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Unit',
                            value: selectedUnit,
                            items: AppConstants.units,
                            icon: Icons.straighten_rounded,
                            onChanged: (value) => onUnitChanged(value!),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildDropdown(
                          label: 'Category',
                          value: selectedCategory,
                          items: AppConstants.categories,
                          icon: Icons.category_rounded,
                          onChanged: (value) => onCategoryChanged(value!),
                        ),
                        const SizedBox(height: 20),
                        _buildDropdown(
                          label: 'Unit',
                          value: selectedUnit,
                          items: AppConstants.units,
                          icon: Icons.straighten_rounded,
                          onChanged: (value) => onUnitChanged(value!),
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppConstants.primaryColor,
            size: 18,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
        filled: true,
        fillColor: AppConstants.backgroundColor,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppConstants.primaryColor,
            size: 18,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
        filled: true,
        fillColor: AppConstants.backgroundColor,
      ),
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPublishButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: AppConstants.primaryColor.withOpacity(0.3),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEditMode ? Icons.update_rounded : Icons.publish_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditMode ? 'Update Item' : 'Publish Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}