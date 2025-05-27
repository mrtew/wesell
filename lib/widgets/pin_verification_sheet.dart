import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import 'custom_dialog.dart';

class PinVerificationSheet extends ConsumerStatefulWidget {
  final Function(bool) onVerificationComplete;
  final String title;

  const PinVerificationSheet({
    super.key,
    required this.onVerificationComplete,
    this.title = 'Enter PIN',
  });

  @override
  ConsumerState<PinVerificationSheet> createState() => _PinVerificationSheetState();
}

class _PinVerificationSheetState extends ConsumerState<PinVerificationSheet> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _pin = '';
  
  @override
  void initState() {
    super.initState();
    // Automatically focus and show keyboard when sheet loads
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
      
      // Validate PIN when 6 digits are entered
      if (_pin.length == 6) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _validatePin();
        });
      }
    });
  }

  void _validatePin() {
    final user = ref.read(currentUserProvider).value;
    if (_pin == user?.pin.toString()) {
      // PIN is correct
      widget.onVerificationComplete(true);
      Navigator.pop(context);
    } else {
      // PIN is incorrect, show error dialog
      showCustomDialog(
        context: context,
        title: "Error",
        content: "Incorrect PIN. Please try again.",
        buttonText2: "OK",
        onPressed2: () {
          // Clear the input field
          _pinController.clear();
          _pin = '';
          // Ensure focus is on the input field
          FocusScope.of(context).requestFocus(_focusNode);
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
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
          const SizedBox(height: 32),
          
          // Cancel button
          TextButton(
            onPressed: () {
              widget.onVerificationComplete(false);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 