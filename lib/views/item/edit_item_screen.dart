import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import '../../providers/user_provider.dart';
import '../../widgets/app_bar_widget.dart';
import '../../utils/categories.dart';
import '../../providers/item_provider.dart';
import '../../models/item_model.dart';
import '../../utils/currency_formatter.dart';

// Function to compress image in isolate
Future<Uint8List> _compressImageInIsolate(Uint8List imageBytes) async {
  return await compute(_compressImageBytes, imageBytes);
}

// Static function for image compression (runs in isolate)
Uint8List _compressImageBytes(Uint8List imageBytes) {
  // Decode image
  img.Image? image = img.decodeImage(imageBytes);
  if (image == null) return imageBytes;

  // Calculate new dimensions while maintaining aspect ratio
  int maxWidth = 800;
  int maxHeight = 800;
  
  int newWidth = image.width;
  int newHeight = image.height;
  
  if (image.width > maxWidth || image.height > maxHeight) {
    double widthRatio = maxWidth / image.width;
    double heightRatio = maxHeight / image.height;
    double ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
    
    newWidth = (image.width * ratio).round();
    newHeight = (image.height * ratio).round();
  }
  
  // Resize image if needed
  if (newWidth != image.width || newHeight != image.height) {
    image = img.copyResize(image, width: newWidth, height: newHeight);
  }
  
  // Encode as JPEG with quality 85%
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

// Provider for editing an item
final editItemProvider = FutureProvider.family<bool, Map<String, dynamic>>((ref, itemData) async {
  final itemController = ref.read(itemControllerProvider);
  
  await itemController.updateItem(
    itemId: itemData['itemId'] as String,
    title: itemData['title'] as String,
    description: itemData['description'] as String,
    category: itemData['category'] as String,
    originalPrice: itemData['originalPrice'] as double,
    price: itemData['price'] as double,
    newImages: itemData['newImages'] as List<File>?, // Compressed images for upload
    originalNewImages: itemData['originalNewImages'] as List<File>?, // Original images for ML Kit
    removedImageUrls: itemData['removedImageUrls'] as List<String>?,
    existingImageUrls: itemData['existingImageUrls'] as List<String>?,
  );
  
  return true;
});

class EditItemScreen extends ConsumerStatefulWidget {
  final String itemId;

  const EditItemScreen({required this.itemId, super.key});

  @override
  ConsumerState<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends ConsumerState<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  String _selectedCategory = categories.first.id;
  List<File> _newImageFiles = [];
  List<String> _existingImageUrls = [];
  List<String> _removedImageUrls = [];
  bool _isLoading = true;
  ItemModel? _item;

  // Helper method to compress new images
  Future<List<File>> _compressNewImages(List<File> originalImages) async {
    if (originalImages.isEmpty) return originalImages;
    
    List<File> compressedImages = [];
    
    for (int i = 0; i < originalImages.length; i++) {
      try {
        // Read original image bytes
        final originalBytes = await originalImages[i].readAsBytes();
        
        // Compress image in background isolate
        final compressedBytes = await _compressImageInIsolate(originalBytes);
        
        // Create temporary file for compressed image
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/compressed_edit_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await tempFile.writeAsBytes(compressedBytes);
        
        compressedImages.add(tempFile);
      } catch (e) {
        // If compression fails, use original image
        compressedImages.add(originalImages[i]);
      }
    }
    
    return compressedImages;
  }

  @override
  void initState() {
    super.initState();
    _loadItemData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadItemData() async {
    try {
      final itemAsync = await ref.read(itemByIdProvider(widget.itemId).future);
      
      if (itemAsync == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item not found')),
          );
          GoRouter.of(context).pop();
        }
        return;
      }
      
      _item = itemAsync;
      
      // Set form fields
      _titleController.text = _item!.title;
      _descriptionController.text = _item!.description;
      _priceController.text = formatMoney(_item!.price);
      _originalPriceController.text = formatMoney(_item!.originalPrice);
      _selectedCategory = _item!.category;
      _existingImageUrls = List<String>.from(_item!.images);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading item: $e')),
        );
        GoRouter.of(context).pop();
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImageFiles.addAll(pickedFiles.map((xFile) => File(xFile.path)).toList());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      
      if (pickedFile != null) {
        setState(() {
          _newImageFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      final imageUrl = _existingImageUrls[index];
      _removedImageUrls.add(imageUrl);
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')),
        );
        return;
      }

      // Show modal dialog to prevent navigation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Saving changes...'),
                SizedBox(height: 8),
                Text('Please wait'),
              ],
            ),
          ),
        ),
      );

      try {
        // Convert price string to double
        final price = double.parse(_priceController.text.replaceAll(',', ''));
        final originalPrice = double.parse(_originalPriceController.text.replaceAll(',', ''));

        // Compress new images before uploading (if any)
        List<File>? compressedNewImages;
        if (_newImageFiles.isNotEmpty) {
          compressedNewImages = await _compressNewImages(_newImageFiles);
        }

        // Create item data map
        final itemData = {
          'itemId': widget.itemId,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'category': _selectedCategory,
          'price': price,
          'originalPrice': originalPrice,
          'newImages': compressedNewImages,
          'originalNewImages': _newImageFiles.isNotEmpty ? _newImageFiles : null, // For ML Kit if needed
          'removedImageUrls': _removedImageUrls.isNotEmpty ? _removedImageUrls : null,
          'existingImageUrls': _existingImageUrls,
        };

        // Call provider to update item
        await ref.read(editItemProvider(itemData).future);
        
        // Clean up temporary compressed files
        if (compressedNewImages != null) {
          for (var file in compressedNewImages) {
            if (file.path.contains('compressed_edit_')) {
              try {
                await file.delete();
              } catch (e) {
                // Ignore cleanup errors
              }
            }
          }
        }
        
        // Refresh data
        ref.refresh(itemByIdProvider(widget.itemId));
        ref.refresh(currentUserProvider);
        
        // Close dialog and navigate back
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          GoRouter.of(context).pop(true); // Return true to indicate success
          
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Item updated successfully!')),
          );
        }
      } catch (e) {
        // Clean up any temporary compressed files in case of error
        try {
          final tempDir = Directory.systemTemp;
          final files = await tempDir.list().toList();
          for (var file in files) {
            if (file is File && file.path.contains('compressed_edit_')) {
              await file.delete();
            }
          }
        } catch (cleanupError) {
          // Ignore cleanup errors
        }
        
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating item: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Edit Item',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit your item information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildImagePicker(),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildCategoryDropdown(),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                            prefixText: 'RM ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price';
                            }
                            try {
                              double.parse(value.replaceAll(',', ''));
                            } catch (e) {
                              return 'Please enter a valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _originalPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Original Price',
                            border: OutlineInputBorder(),
                            prefixText: 'RM ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the original price';
                            }
                            try {
                              double.parse(value.replaceAll(',', ''));
                            } catch (e) {
                              return 'Please enter a valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Text(
        //   'Images',
        //   style: TextStyle(
        //     fontSize: 16,
        //     fontWeight: FontWeight.bold,
        //   ),
        // ),
        // const SizedBox(height: 8),
        // Text(
        //   'Add up to 5 images',
        //   style: TextStyle(
        //     fontSize: 14,
        //     color: Colors.grey[600],
        //   ),
        // ),
        // const SizedBox(height: 16),
        Row(
          children: [
            _buildImageContainer(
              onTap: _pickImages,
              icon: Icons.photo_library,
              label: 'Upload Photos',
            ),
            const SizedBox(width: 16),
            _buildImageContainer(
              onTap: _takePicture,
              icon: Icons.camera_alt,
              label: 'Take Photo',
            ),
          ],
        ),
        if (_existingImageUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Current Images',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImageUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _existingImageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        if (_newImageFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'New Images',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _newImageFiles.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _newImageFiles[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeNewImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageContainer({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      value: _selectedCategory,
      items: categories.map((category) {
        return DropdownMenuItem<String>(
          value: category.id,
          child: Row(
            children: [
              Icon(category.icon, size: 20),
              const SizedBox(width: 8),
              Text(category.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory = value;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
    );
  }
} 