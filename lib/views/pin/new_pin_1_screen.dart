import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_bar_widget.dart';

class NewPin1Screen extends ConsumerStatefulWidget {
  const NewPin1Screen({super.key});

  @override
  ConsumerState<NewPin1Screen> createState() => _NewPin1ScreenState();
}

class _NewPin1ScreenState extends ConsumerState<NewPin1Screen> {
  // Single controller for the hidden input field
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _pin = '';
  
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
      _pin = _pinController.text;
      // Limit to 6 digits
      if (_pin.length > 6) {
        _pin = _pin.substring(0, 6);
        _pinController.text = _pin;
        _pinController.selection = TextSelection.fromPosition(
          TextPosition(offset: _pin.length),
        );
      }
      
      // Navigate to next screen when 6 digits are entered
      if (_pin.length == 6) {
        Future.delayed(const Duration(milliseconds: 200), () {
          GoRouter.of(context).push('/new_pin_2', extra: _pin);
        });
      }
    });
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
        title: 'Set New PIN',
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
                    'Enter 6-digit PIN',
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
                      final isFilled = _pin.length > index;
                      
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