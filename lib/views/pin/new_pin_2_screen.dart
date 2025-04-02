import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import '../../controllers/user_controller.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/custom_dialog.dart';

class NewPin2Screen extends ConsumerStatefulWidget {
  final String pin;
  const NewPin2Screen({super.key, required this.pin});

  @override
  ConsumerState<NewPin2Screen> createState() => _NewPin2ScreenState();
}

class _NewPin2ScreenState extends ConsumerState<NewPin2Screen> {
  // Single controller for the hidden input field
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _confirmPin = '';
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
    // Automatically focus and show keyboard when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
    
    // Listen to changes in the text field
    _pinController.addListener(_updatePinDisplay);
  }
  
  void _updatePinDisplay() {
    setState(() {
      _confirmPin = _pinController.text;
      // Limit to 6 digits
      if (_confirmPin.length > 6) {
        _confirmPin = _confirmPin.substring(0, 6);
        _pinController.text = _confirmPin;
        _pinController.selection = TextSelection.fromPosition(
          TextPosition(offset: _confirmPin.length),
        );
      }
      
      // Validate PIN when 6 digits are entered
      if (_confirmPin.length == 6) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _validatePin();
        });
      }
    });
  }

  void _validatePin() async{
    if (_confirmPin == widget.pin) {
      // Get current user
      final user = ref.read(currentUserProvider).value;
      final userController = ref.read(userControllerProvider);
      
      if (user != null) {
        // Update the user's PIN in Firestore
        final updatedUser = user.copyWith(
          pin: widget.pin,
          updatedAt: Timestamp.now(),
        );
        
        try {
          await userController.updateUser(updatedUser);
          
          showCustomDialog(
            context: context,
            title: "Success",
            content: "Your PIN has been set up successfully.",
            buttonText2: "Proceed",
            onPressed2: () {
              context.go('/me');
              GoRouter.of(context).push('/balance');
            },
          );
        } catch (e) {
          showCustomDialog(
            context: context,
            title: "Error",
            content: "Failed to update PIN. Please try again.",
            buttonText2: "OK",
            onPressed2: () {
              // Clear the input field
              _pinController.clear();
              _confirmPin = '';
            },
          );
        }
      }
    } else {
      showCustomDialog(
        context: context,
        title: "Error",
        content: "PINs do not match. Please try again.",
        buttonText2: "OK",
        onPressed2: () {
          // Clear the input field when PINs don't match
          _pinController.clear();
          _confirmPin = '';
        },
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Confirm New PIN',
        showBackButton: true,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          
          return GestureDetector(
            // Refocus on the hidden field if user taps anywhere
            onTap: () => FocusScope.of(context).requestFocus(_focusNode),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Confirm 6-digit PIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // PIN Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      // Determine if this digit has been entered
                      final isFilled = _confirmPin.length > index;
                      
                      return Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFilled 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey.shade300,
                            width: isFilled ? 2 : 1.5,
                          ),
                          color: Colors.grey.shade300,
                        ),
                        alignment: Alignment.center,
                        child: isFilled
                            ? const Text(
                                '•', // Dot for obscuring the PIN
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    }),
                  ),
                  
                  // Hidden text field that captures input
                  Opacity(
                    opacity: 0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _pinController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        autofocus: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: ${error.toString()}')),
      ),
    );
  }
}