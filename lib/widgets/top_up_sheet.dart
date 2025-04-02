import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/transaction_controller.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../services/stripe_service.dart';
import 'pin_verification_sheet.dart';
import 'custom_dialog.dart';

class TopUpSheet extends ConsumerStatefulWidget {
  final Function() onTopUpComplete;

  const TopUpSheet({
    super.key,
    required this.onTopUpComplete,
  });

  @override
  ConsumerState<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<TopUpSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  
  double _selectedAmount = 0.0;
  bool _isLoading = false;
  bool _showCardInputs = false;
  
  final List<double> _presetAmounts = [1.00, 5.00, 10.00, 20.00, 50.00, 100.00];

  @override
  void initState() {
    super.initState();
    // Set default test card for convenience in testing
    _cardNumberController.text = "4242 4242 4242 4242";
    _expiryController.text = "12/30";
    _cvcController.text = "123";
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(2);
    });
  }

  // Format card number with spaces
  String _formatCardNumber(String text) {
    if (text.isEmpty) return '';
    
    // Remove all spaces
    text = text.replaceAll(' ', '');
    
    final result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        result.write(' ');
      }
      result.write(text[i]);
    }
    
    return result.toString();
  }

  // Format expiry date (MM/YY)
  String _formatExpiryDate(String text) {
    if (text.isEmpty) return '';
    
    // Remove all slashes
    text = text.replaceAll('/', '');
    
    if (text.length > 2) {
      return '${text.substring(0, 2)}/${text.substring(2)}';
    }
    
    return text;
  }

  Future<void> _proceedToCardInput() async {
    // Parse the amount
    String amountText = _amountController.text;
    if (amountText.isEmpty) {
      showCustomDialog(
        context: context,
        title: "Error",
        content: "Please enter an amount.",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showCustomDialog(
        context: context,
        title: "Error",
        content: "Please enter a valid amount greater than 0.",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }

    // Show card input
    setState(() {
      _showCardInputs = true;
    });
  }

  Future<void> _proceedToPayment() async {
    // Validate card inputs
    if (_cardNumberController.text.replaceAll(' ', '').length < 16) {
      showCustomDialog(
        context: context,
        title: "Error",
        content: "Please enter a valid card number.",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }

    if (_expiryController.text.length < 5) {
      showCustomDialog(
        context: context,
        title: "Error",
        content: "Please enter a valid expiry date (MM/YY).",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }

    if (_cvcController.text.length < 3) {
      showCustomDialog(
        context: context,
        title: "Error",
        content: "Please enter a valid CVC code.",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }

    // Verify PIN
    _verifyPin();
  }

  void _verifyPin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PinVerificationSheet(
          title: 'Enter PIN to confirm payment',
          onVerificationComplete: (success) {
            if (success) {
              _processPayment();
            }
          },
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      // Parse amount to cents (integer)
      final double amountDouble = double.parse(_amountController.text);
      final int amountCents = (amountDouble * 100).round();
      
      // Simulate payment - this will now just return true after a delay
      final success = await StripeService.presentPaymentSheet(
        context, 
        amountCents, // Already in cents
        'myr',
      );

      if (success) {
        // Process top-up in database
        final user = ref.read(currentUserProvider).value;
        final transactionController = ref.read(transactionControllerProvider);
        
        if (user != null) {
          final topUpSuccess = await transactionController.processTopUp(
            user.uid,
            amountCents,
            {
              'paymentMethod': 'card',
              'cardBrand': 'visa',
              'cardNumber': _cardNumberController.text.replaceAll(' ', ''),
            },
          );
          
          if (topUpSuccess) {
            // Refresh user data to get updated balance
            Future.microtask(() => ref.refresh(currentUserProvider));
            
            // Show success message
            showCustomDialog(
              context: context,
              title: "Success",
              content: "Your wallet has been topped up with RM${amountDouble.toStringAsFixed(2)}.",
              buttonText2: "OK",
              onPressed2: () {
                Navigator.pop(context); // Close the bottom sheet
                widget.onTopUpComplete();
              },
            );
          } else {
            _showErrorDialog("Failed to process top-up. Please try again.");
          }
        }
      } else {
        _showErrorDialog("Payment was canceled or failed.");
      }
    } catch (e) {
      _showErrorDialog("An error occurred: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showCustomDialog(
      context: context,
      title: "Error",
      content: message,
      buttonText2: "OK",
      onPressed2: () {},
    );
  }

  Widget _buildCardInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Card Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Card number input with card icons
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            TextInputFormatter.withFunction((oldValue, newValue) {
              final text = _formatCardNumber(newValue.text);
              return TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: text.length),
              );
            }),
          ],
          decoration: InputDecoration(
            labelText: 'Card number',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network('https://www.pngall.com/wp-content/uploads/2017/05/Visa-Logo-Free-Download-PNG.png', width: 30, height: 30, errorBuilder: (context, error, stackTrace) => const Icon(Icons.credit_card, color: Colors.blue)),
                const SizedBox(width: 5),
                Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Mastercard-logo.svg/1280px-Mastercard-logo.svg.png', width: 30, height: 30, errorBuilder: (context, error, stackTrace) => const Icon(Icons.credit_card, color: Colors.red)),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Row for expiry date and CVC
        Row(
          children: [
            // Expiry date
            Expanded(
              child: TextField(
                controller: _expiryController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = _formatExpiryDate(newValue.text);
                    return TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }),
                ],
                decoration: const InputDecoration(
                  labelText: 'MM/YY',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // CVC
            Expanded(
              child: TextField(
                controller: _cvcController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'CVC',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.info_outline, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Payment button
        ElevatedButton(
          onPressed: _isLoading ? null : _proceedToPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Pay', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        
        // Cancel button
        TextButton(
          onPressed: () {
            setState(() {
              _showCardInputs = false;
            });
          },
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildAmountInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Up Wallet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.credit_card),
          ],
        ),
        const SizedBox(height: 24),
        
        // Amount input
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Amount (RM)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
        ),
        const SizedBox(height: 16),
        
        // Preset amounts
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetAmounts.map((amount) {
            final isSelected = _selectedAmount == amount;
            return InkWell(
              onTap: () => _selectAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'RM${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        
        // Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel', style: TextStyle(color: Colors.black)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _proceedToCardInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Show different content based on the current step
          if (_showCardInputs) 
            _buildCardInputForm()
          else 
            _buildAmountInputForm(),
          
          // Test card info always visible
          if (!_showCardInputs) ...[
            const Divider(),
            const Text(
              'Test Card: 4242 4242 4242 4242',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Text(
              'Any future date, any 3 digits for CVC',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
} 