import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../widgets/app_bar_widget.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

class PassportVerificationScreen extends ConsumerStatefulWidget {
  const PassportVerificationScreen({super.key});

  @override
  ConsumerState<PassportVerificationScreen> createState() => _PassportVerificationScreenState();
}

class _PassportVerificationScreenState extends ConsumerState<PassportVerificationScreen> {
  File? _frontImage;
  File? _backImage;
  File? _faceImage;
  bool _isProcessing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passportNumberController = TextEditingController();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void dispose() {
    _nameController.dispose();
    _passportNumberController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Passport Verification',
        showBackButton: true,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: ${error.toString()}')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please upload clear images of the front and back of your Passport',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                
                // Front of Passport
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Front Page of Passport',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This must clearly show your photo, name, and passport number',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        
                        // Front Image Preview
                        Center(
                          child: GestureDetector(
                            onTap: () => _pickImage(context, true),
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: _frontImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _frontImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 60,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to upload front page of Passport',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        
                        if (_isProcessing)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(height: 8),
                                  Text('Processing image...'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Back of Passport
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Back Page of Passport',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This must clearly show additional information from your passport',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        
                        // Back Image Preview
                        Center(
                          child: GestureDetector(
                            onTap: () => _pickImage(context, false),
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: _backImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _backImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 60,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to upload back page of Passport',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Face Image
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Face Photo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please upload a clear photo of your face',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        
                        // Face Image Preview
                        Center(
                          child: GestureDetector(
                            onTap: () => _pickImage(context, false, isFace: true),
                            child: Container(
                              width: double.infinity,
                              height: 400,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: _faceImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _faceImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 60,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to upload face photo',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Passport Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Passport Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            enabled: false,
                          ),
                          readOnly: true,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Passport Number
                        TextFormField(
                          controller: _passportNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Passport Number',
                            border: OutlineInputBorder(),
                            enabled: false,
                          ),
                          readOnly: true,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _frontImage == null || _backImage == null || _faceImage == null || _nameController.text.isEmpty || _passportNumberController.text.isEmpty
                        ? null
                        : () => _submitVerification(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Submit Verification'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, bool isFront, {bool isFace = false}) async {
    // Request permission
    final status = await Permission.photos.request();

    if (status.isGranted) {
      await _openGallery(isFront, isFace: isFace);
    } else if (status.isDenied) {
      _showPermissionDeniedDialog();
    } else if (status.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedDialog();
    }
  }

  Future<void> _openGallery(bool isFront, {bool isFace = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (isFace) {
          _faceImage = File(pickedFile.path);
        } else if (isFront) {
          _frontImage = File(pickedFile.path);
          // Process front image with OCR
          _processImageWithOCR(_frontImage!);
        } else {
          _backImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _processImageWithOCR(File imageFile) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String text = recognizedText.text;
      
      // Extract name and passport number from the text
      String name = '';
      String passportNumber = '';
      
      // Look for passport number - typically in formats like A12345678, 12345678X
      // Different countries have different formats, this is a general approach
      final RegExp passportRegex = RegExp(r'[A-Z0-9]{7,10}');
      final Iterable<Match> matches = passportRegex.allMatches(text);
      
      for (final Match match in matches) {
        final String candidate = match.group(0)!;
        // Passport numbers typically have a mix of letters and numbers
        if (RegExp(r'[A-Z]').hasMatch(candidate) && RegExp(r'[0-9]').hasMatch(candidate)) {
          passportNumber = candidate;
          break;
        }
      }
      
      // Try to find the name - this is more complex
      // Look for patterns like "Name: [name]" or "Surname/Given Names"
      for (TextBlock block in recognizedText.blocks) {
        String blockText = block.text.trim();
        // print(blockText);
        // Look for blocks containing name indicators
        if (blockText.contains('P<')) {
          blockText = blockText.substring(blockText.indexOf("YS") + 2, blockText.indexOf("<<<"))
                                .split('<')
                                .where((s) => s.isNotEmpty)
                                .join(' ');

          name = blockText;
          
          // Extract name from this block
        //   List<String> lines = blockText.split('\n');
        //   for (String line in lines) {
        //     if (line.contains('Name:')) {
        //       name = line.replaceAll('Name:', '').trim();
        //       break;
        //     }
        //     if (name.isEmpty && 
        //         (line.contains('Surname') || line.contains('Given name'))) {
        //       // Get the next line as it might contain the name
        //       int index = lines.indexOf(line);
        //       if (index < lines.length - 1) {
        //         name = lines[index + 1].trim();
        //         break;
        //       }
        //     }
        //   }
          
        //   if (name.isNotEmpty) break;
        }
        
        // If we couldn't find a clear name indicator, look for lines with mostly letters
        // if (name.isEmpty && 
        //     blockText.length > 5 && 
        //     !blockText.contains(passportNumber) &&
        //     RegExp(r'^[A-Za-z\s]+$').hasMatch(blockText)) {
        //   name = blockText;
        //   break;
        // }
      }
      
      setState(() {
        _nameController.text = name;
        _passportNumberController.text = passportNumber;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Gallery access permission is required to select a passport photo. Please grant the permission to continue.',
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

  Future<void> _submitVerification(UserModel user) async {
    if (_frontImage == null || _backImage == null || _faceImage == null || _nameController.text.isEmpty || _passportNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
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
              Text('Submitting verification...'),
              SizedBox(height: 8),
              Text('Please wait'),
            ],
          ),
        ),
      ),
    );

    try {
      // Generate unique filenames with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final frontFileName = '${user.uid}_passport_front_$timestamp.jpg';
      final backFileName = '${user.uid}_passport_back_$timestamp.jpg';
      final faceFileName = '${user.uid}_face_$timestamp.jpg';
      
      // Create storage references
      final storageRef = FirebaseStorage.instance.ref();
      final frontImageRef = storageRef.child('users/${user.uid}/identity/$frontFileName');
      final backImageRef = storageRef.child('users/${user.uid}/identity/$backFileName');
      final faceImageRef = storageRef.child('users/${user.uid}/identity/$faceFileName');
      
      // Upload images
      await frontImageRef.putFile(_frontImage!);
      final frontImageUrl = await frontImageRef.getDownloadURL();
      
      await backImageRef.putFile(_backImage!);
      final backImageUrl = await backImageRef.getDownloadURL();
      
      await faceImageRef.putFile(_faceImage!);
      final faceImageUrl = await faceImageRef.getDownloadURL();
      
      // Create updated identity map
      final Map<String, String> updatedIdentity = {
        'type': 'passport',
        'name': _nameController.text,
        'id': _passportNumberController.text,
        'frontPath': frontImageUrl,
        'backPath': backImageUrl,
        'facePath': faceImageUrl,
        'createdAt': Timestamp.now().toDate().toIso8601String(),
      };
      
      // Update user in Firebase
      final userController = ref.read(userControllerProvider);
      await userController.updateUser(
        user.copyWith(
          identity: updatedIdentity,
          // isIdentityVerified: true,
          updatedAt: Timestamp.now(),
        ),
      );
      
      // Refresh user data and close dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        await Future.microtask(() => ref.refresh(currentUserProvider));
        
        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identity verification submitted successfully')),
        );
        context.go('/me');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting verification: $e')),
        );
      }
    }
  }
} 