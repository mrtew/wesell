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

  const TopUpSheet({super.key, required this.onTopUpComplete});

  @override
  ConsumerState<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<TopUpSheet> {
  final TextEditingController _amountController = TextEditingController();

  double _selectedAmount = 0.0;
  bool _isLoading = false;

  final List<double> _presetAmounts = [2.00, 5.00, 10.00, 20.00, 50.00, 100.00];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(2);
    });
  }

  Future<void> _proceedToPayment() async {
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
        content: "The minimum top-up amount is RM2.00.",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }

    // Check minimum amount requirement
    if (amount < 2.00) {
      showCustomDialog(
        context: context,
        title: "Minimum Amount Required",
        content: "The minimum top-up amount is RM2.00.",
        buttonText2: "OK",
        onPressed2: () {},
      );
      return;
    }

    // Show Stripe payment sheet first
    _showStripePayment();
  }

  Future<void> _showStripePayment() async {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      // Parse amount to cents (integer)
      final double amountDouble = double.parse(_amountController.text);
      final int amountCents = (amountDouble * 100).round();

      // Process payment with Stripe (this will show Stripe's payment sheet)
      final success = await StripeService.presentPaymentSheet(
        context,
        amountCents, // Already in cents
        'myr',
      );

      if (success) {
        // After successful Stripe payment, verify PIN
        _verifyPin();
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

  void _verifyPin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: PinVerificationSheet(
              title: 'Enter PIN to confirm top-up',
              onVerificationComplete: (success) {
                if (success) {
                  _processTopUp();
                }
              },
            ),
          ),
    );
  }

  Future<void> _processTopUp() async {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      // Parse amount to cents (integer)
      final double amountDouble = double.parse(_amountController.text);
      final int amountCents = (amountDouble * 100).round();

      // Process top-up in database
      final user = ref.read(currentUserProvider).value;
      final transactionController = ref.read(transactionControllerProvider);

      if (user != null) {
        final topUpSuccess = await transactionController.processTopUp(
          user.uid,
          amountCents,
          {
            'paymentMethod': 'card',
            'cardBrand': 'visa', // You can get this from Stripe if needed
            'amount': amountDouble,
          },
        );

        if (topUpSuccess) {
          // Refresh user data to get updated balance
          Future.microtask(() => ref.refresh(currentUserProvider));

          // Show success message
          showCustomDialog(
            context: context,
            title: "Success",
            content:
                "Your wallet has been topped up with RM${amountDouble.toStringAsFixed(2)}.",
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Up Wallet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              helperText: 'Minimum amount: RM2.00',
            ),
          ),
          const SizedBox(height: 16),

          // Preset amounts (updated to start from 2.00)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _presetAmounts.map((amount) {
                  final isSelected = _selectedAmount == amount;
                  return InkWell(
                    onTap: () => _selectAmount(amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'RM${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _proceedToPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Continue',
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),
            ],
          ),

          // Payment flow info
          const SizedBox(height: 16),
          const Divider(),
          // const Text(
          //   'Payment Flow: Enter Amount → Stripe Payment → PIN Verification',
          //   style: TextStyle(fontSize: 12, color: Colors.grey),
          //   textAlign: TextAlign.center,
          // ),
          // const Text(
          //   'Minimum top-up amount: RM2.00',
          //   style: TextStyle(fontSize: 12, color: Colors.grey),
          //   textAlign: TextAlign.center,
          // ),
          // const SizedBox(height: 4),
        ],
      ),
    );
  }
}
