import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import '../../widgets/app_bar_widget.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/cached_avatar_widget.dart';

// Compression parameters class for isolate
class CompressionParams {
  final Uint8List imageBytes;
  final String originalPath;

  CompressionParams({
    required this.imageBytes,
    required this.originalPath,
  });
}

// Compression result class
class CompressionResult {
  final Uint8List compressedBytes;
  final String tempPath;
  final bool wasCompressed;

  CompressionResult({
    required this.compressedBytes,
    required this.tempPath,
    required this.wasCompressed,
  });
}

// Top-level function for background image compression (required for compute())
Future<CompressionResult> _compressImageInBackground(CompressionParams params) async {
  try {
    // Decode image
    img.Image? image = img.decodeImage(params.imageBytes);
    if (image == null) {
      return CompressionResult(
        compressedBytes: params.imageBytes,
        tempPath: '${params.originalPath}_original.jpg',
        wasCompressed: false,
      );
    }
    
    // Only compress if image is larger than 800px or file size > 500KB
    final needsCompression = image.width > 800 || image.height > 800 || params.imageBytes.length > 500000;
    
    if (!needsCompression) {
      return CompressionResult(
        compressedBytes: params.imageBytes,
        tempPath: '${params.originalPath}_original.jpg',
        wasCompressed: false,
      );
    }
    
    // Calculate new dimensions while maintaining aspect ratio
    int newWidth = image.width;
    int newHeight = image.height;
    
    if (image.width > image.height) {
      if (newWidth > 800) {
        newWidth = 800;
        newHeight = (800 * image.height / image.width).round();
      }
    } else {
      if (newHeight > 800) {
        newHeight = 800;
        newWidth = (800 * image.width / image.height).round();
      }
    }
    
    // Resize image with optimized settings
    img.Image resizedImage = img.copyResize(
      image, 
      width: newWidth, 
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
    
    // Compress with good quality/size balance
    final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
    
    debugPrint('Image compressed: ${params.imageBytes.length} bytes -> ${compressedBytes.length} bytes');
    
    return CompressionResult(
      compressedBytes: Uint8List.fromList(compressedBytes),
      tempPath: '${params.originalPath}_compressed.jpg',
      wasCompressed: true,
    );
  } catch (e) {
    debugPrint('Error compressing image: $e');
    return CompressionResult(
      compressedBytes: params.imageBytes,
      tempPath: '${params.originalPath}_original.jpg',
      wasCompressed: false,
    );
  }
}

class EditAvatarScreen extends ConsumerStatefulWidget {
  const EditAvatarScreen({super.key});

  @override
  ConsumerState<EditAvatarScreen> createState() => _EditAvatarScreenState();
}

class _EditAvatarScreenState extends ConsumerState<EditAvatarScreen> {
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Edit Profile Photo',
        showBackButton: true,
      ),
      body: ref.watch(currentUserProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return Column(
            children: [
              const SizedBox(height: 20),
              
              // Avatar preview
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CachedAvatarWidget(
                          avatarUrl: user.avatar.isNotEmpty ? user.avatar : null,
                          width: 200,
                          height: 200,
                          borderRadius: 8,
                          iconSize: 80,
                        ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Select photo button
              ElevatedButton.icon(
                onPressed: () => _pickImage(context),
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Upload button
              if (_selectedImage != null)
                ElevatedButton.icon(
                  onPressed: () => _uploadImage(user),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    // Request permission
    final status = await Permission.photos.request();

    if (status.isGranted) {
      _openGallery();
    } else if (status.isDenied) {
      _showPermissionDeniedDialog();
    } else if (status.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedDialog();
    }
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
    
    // if (pickedFile != null) {
    //   final croppedFile = await _cropImage(File(pickedFile.path));
    //   if (croppedFile != null) {
    //     setState(() {
    //       _selectedImage = File(croppedFile.path);
    //     });
    //   }
    // }
  }

  // Future<CroppedFile?> _cropImage(File imageFile) async {
  //   return await ImageCropper().cropImage(
  //     sourcePath: imageFile.path,
  //     aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
  //     compressQuality: 70,
  //     compressFormat: ImageCompressFormat.jpg,
  //     uiSettings: [
  //       AndroidUiSettings(
  //         toolbarTitle: 'Crop Image',
  //         toolbarColor: Colors.green,
  //         toolbarWidgetColor: Colors.white,
  //         initAspectRatio: CropAspectRatioPreset.square,
  //         lockAspectRatio: true,
  //         hideBottomControls: false,
  //       ),
  //       IOSUiSettings(
  //         title: 'Crop Image',
  //         aspectRatioLockEnabled: true,
  //         resetAspectRatioEnabled: false,
  //       ),
  //     ],
  //   );
  // }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Gallery access permission is required to select a profile photo. Please grant the permission to continue.',
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permission Permanently Denied'),
        content: const Text(
          'Gallery access permission is permanently denied. Please enable it from app settings.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  // Compress image in background isolate to prevent UI freeze
  Future<File?> _compressImage(File imageFile) async {
    try {
      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      
      // Create compression parameters
      final params = CompressionParams(
        imageBytes: imageBytes,
        originalPath: imageFile.path,
      );
      
      // Run compression in background isolate (won't block UI)
      final result = await compute(_compressImageInBackground, params);
      
      // Create file with compressed data
      final compressedFile = File(result.tempPath);
      await compressedFile.writeAsBytes(result.compressedBytes);
      
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageFile; // Return original file if compression fails
    }
  }

  // Show upload dialog
  void _showUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => PopScope(
        canPop: false, // Prevent back button from dismissing
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uploading Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we upload your photo...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadImage(UserModel user) async {
    if (_selectedImage == null) return;

    // Show upload dialog first
    _showUploadDialog();

    try {
      // Compress the image first
      final compressedImage = await _compressImage(_selectedImage!);
      if (compressedImage == null) {
        throw Exception('Failed to process image');
      }

      // Generate a unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_avatar_$timestamp.jpg';
      
      // Create storage reference
      final storageRef = FirebaseStorage.instance.ref();
      final avatarRef = storageRef.child('users/${user.uid}/avatar/$fileName');
      
      // Upload compressed file
      await avatarRef.putFile(compressedImage);
      
      // Get download URL
      final downloadUrl = await avatarRef.getDownloadURL();
      
      // Clean up compressed file if it's different from original
      if (compressedImage.path != _selectedImage!.path) {
        try {
          await compressedImage.delete();
        } catch (e) {
          debugPrint('Could not delete compressed file: $e');
        }
      }
      
      // Update user avatar in Firestore
      final userController = ref.read(userControllerProvider);
      await userController.updateUser(
        user.copyWith(
          avatar: downloadUrl,
          updatedAt: Timestamp.now(),
        ),
      );
      
      // Refresh user data
      await Future.microtask(() => ref.refresh(currentUserProvider));
      
      // Close upload dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        
        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully')),
        );
        GoRouter.of(context).pop(); // Go back to previous screen
      }
    } catch (e) {
      // Close upload dialog first
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile photo: $e')),
        );
      }
    }
  }
} 