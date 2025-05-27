import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../controllers/admin_controller.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';

class VerifyUserScreen extends ConsumerStatefulWidget {
  final String userId;
  
  const VerifyUserScreen({
    required this.userId,
    super.key,
  });

  @override
  ConsumerState<VerifyUserScreen> createState() => _VerifyUserScreenState();
}

class _VerifyUserScreenState extends ConsumerState<VerifyUserScreen> {
  final AdminController _adminController = AdminController();
  bool _isLoading = true;
  UserModel? _user;
  String? _errorMessage;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  // Load user data
  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Get user data from pending users list
      final pendingUsers = await _adminController.getPendingVerificationUsers();
      _user = pendingUsers.firstWhere(
        (user) => user.uid == widget.userId,
        orElse: () => throw Exception('User not found'),
      );
      
      if (_user == null) {
        throw Exception('User not found');
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Approve user verification
  Future<void> _approveUser() async {
    if (_user == null || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      await _adminController.approveUserVerification(_user!.uid);
      
      if (!mounted) return;
      
      // Show success dialog
      await _showResultDialog(
        title: 'Success',
        message: 'You have approved ${_user?.username.isNotEmpty == true ? _user!.username : 'this user'}\'s identity verification.',
        isSuccess: true,
      );
      
      // Navigate back to user list
      if (!mounted) return;
      GoRouter.of(context).pop();
      // Refresh user list
      ref.read(pendingVerificationUsersProvider.notifier).fetchUsers();
      
    } catch (e) {
      if (!mounted) return;
      
      // Show error dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  // Reject user verification
  Future<void> _rejectUser() async {
    if (_user == null || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      await _adminController.rejectUserVerification(_user!.uid);
      
      if (!mounted) return;
      
      // Show success dialog
      await _showResultDialog(
        title: 'Rejected',
        message: 'You have rejected ${_user?.username.isNotEmpty == true ? _user!.username : 'this user'}\'s identity verification.',
        isSuccess: false,
      );
      
      // Navigate back to user list
      if (!mounted) return;
      GoRouter.of(context).pop();
      // Refresh user list
      ref.read(pendingVerificationUsersProvider.notifier).fetchUsers();
      
    } catch (e) {
      if (!mounted) return;
      
      // Show error dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  // Show result dialog
  Future<void> _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  // Open photo view gallery
  void _openGallery(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            color: Colors.black,
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: Text(
          'Verify User',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _buildUserVerificationContent(),
    );
  }
  
  Widget _buildUserVerificationContent() {
    // Check if user data is available
    if (_user == null) {
      return const Center(child: Text('User data not available'));
    }
    
    // Extract identity images
    final Map<String, String> identity = _user!.identity;
    final String? frontImage = identity['frontPath'];
    final String? backImage = identity['backPath'];
    final String? faceImage = identity['facePath'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User avatar and username
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            child: _user!.avatar.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: CachedNetworkImage(
                      imageUrl: _user!.avatar,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.person, size: 40),
                    ),
                  )
                : const Icon(Icons.person, size: 40),
          ),
          
          const SizedBox(height: 12),
          
          // Username
          Text(
            _user!.username.isEmpty ? 'New User' : _user!.username,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 32),

          Text(
            'Identity Type:',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_user!.identity['type']?.toUpperCase()}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Name:',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_user!.identity['name']}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'ID:',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_user!.identity['id']}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Front image
          if (frontImage != null && frontImage.isNotEmpty) ...[
            const Text(
              'Front',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            GestureDetector(
              onTap: () => _openGallery(frontImage),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: frontImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 50),
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Back image
          if (backImage != null && backImage.isNotEmpty) ...[
            const Text(
              'Back',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            GestureDetector(
              onTap: () => _openGallery(backImage),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: backImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 50),
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Face image
          if (faceImage != null && faceImage.isNotEmpty) ...[
            const Text(
              'Face',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            GestureDetector(
              onTap: () => _openGallery(faceImage),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: faceImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 50),
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 40),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reject button
              SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _rejectUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 16)),
                ),
              ),
              
              // Accept button
              SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _approveUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
} 