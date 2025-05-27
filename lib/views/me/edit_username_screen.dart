import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
// import '../../controllers/user_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/app_bar_widget.dart';

class EditUsernameScreen extends ConsumerStatefulWidget {
  const EditUsernameScreen({super.key});

  @override
  ConsumerState<EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends ConsumerState<EditUsernameScreen> {
  late TextEditingController _usernameController;
  bool _isValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _usernameController.addListener(_validateUsername);
    
    // Initialize with current username
    Future.microtask(() {
      final userState = ref.read(currentUserProvider);
      userState.whenData((user) {
        if (user != null) {
          _usernameController.text = user.username;
          _validateUsername();
        }
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final username = _usernameController.text;
    setState(() {
      _isValid = username.isNotEmpty && username.length <= 8;
    });
  }

  Future<void> _saveUsername() async {
    if (!_isValid) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final userState = ref.read(currentUserProvider);
      
      userState.whenData((user) async {
        if (user != null) {
          final userController = ref.read(userControllerProvider);
          final updatedUser = user.copyWith(
            username: _usernameController.text,
            updatedAt: Timestamp.now(),
          );
          
          await userController.updateUser(updatedUser);

          // Refresh user data
          await Future.microtask(() => ref.refresh(currentUserProvider));
          await Future.delayed(Duration(seconds: 1));
          if (mounted) {
            // Go back to previous screen
            context.pop();
          }
        }
      });
    } catch (error) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error saving username: $error')),
      // );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Edit Name',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                // hintText: 'Enter a username...',
                border: const UnderlineInputBorder(),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
                errorText: _usernameController.text.isNotEmpty && !_isValid
                    ? 'Username must be 1-8 characters'
                    : null,
              ),
              maxLength: 8,
              style: const TextStyle(fontSize: 16),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a name people will remember.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isValid && !_isLoading ? _saveUsername : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.green,
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(60, 36),
                // padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
