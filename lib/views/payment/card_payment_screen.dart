import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/payment_controller.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';

class CardPaymentScreen extends ConsumerStatefulWidget {
  final String itemId;
  final Map<String, dynamic> paymentData;

  const CardPaymentScreen({
    required this.itemId,
    required this.paymentData,
    super.key,
  });

  @override
  ConsumerState<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends ConsumerState<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  // final _cardHolderController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
    Future.microtask(() => ref.refresh(itemByIdProvider(widget.itemId)));
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    // _cardHolderController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  // Format card number with spaces
  String _formatCardNumber(String text) {
    if (text.isEmpty) return '';

    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    final result = StringBuffer();

    for (var i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        result.write(' ');
      }
      result.write(digitsOnly[i]);
    }

    return result.toString();
  }

  // Format expiry date MM/YY
  String _formatExpiryDate(String text) {
    if (text.isEmpty) return '';

    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length <= 2) {
      return digitsOnly;
    } else {
      return '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, digitsOnly.length.clamp(0, 4))}';
    }
  }

  void _processCardPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final userAsync = ref.read(currentUserProvider);
    final itemAsync = ref.read(itemByIdProvider(widget.itemId));

    userAsync.whenData((buyer) {
      if (buyer == null) {
        _showErrorDialog('User not found');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      itemAsync.whenData((item) async {
        if (item == null) {
          _showErrorDialog('Item not found');
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        // Get seller information
        final sellerAsync = await ref.read(
          sellerByIdProvider(item.sellerId).future,
        );
        if (sellerAsync == null) {
          _showErrorDialog('Seller not found');
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        // Prepare card details
        final cardDetails = {
          'cardNumber': _cardNumberController.text.replaceAll(' ', ''),
          // 'cardHolder': _cardHolderController.text,
          'expiryDate': _expiryDateController.text,
          'cvv': _cvvController.text,
        };

        // Process payment
        final paymentController = ref.read(paymentControllerProvider);
        final success = await paymentController.processCardPayment(
          buyer: buyer,
          seller: sellerAsync,
          item: item,
          paymentDetails: cardDetails,
          paymentMethod: widget.paymentData['paymentMethod'],
          deliveryAddress: widget.paymentData['deliveryAddress'],
        );

        if (success) {
          // Navigate to success screen
          if (mounted) {
            // Use go instead of pop() followed by go() to ensure clean navigation
            GoRouter.of(context).go(
              '/payment/success',
              extra: {
                'itemId': item.itemId,
                'transactionAmount': item.price,
                'sellerId': sellerAsync.uid,
                'title': item.title,
              },
            );
          }
        } else {
          // Navigate to failed screen
          if (mounted) {
            GoRouter.of(context).push('/payment/failed', extra: widget.itemId);
          }
        }
      });
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));

    return Scaffold(
      appBar: const AppBarWidget(title: 'Card Payment', showBackButton: true),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(child: Text('Error: ${error.toString()}')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return itemAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, stack) =>
                    Center(child: Text('Error: ${error.toString()}')),
            data: (item) {
              if (item == null) {
                return const Center(child: Text('Item not found'));
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount to pay
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'RM${formatMoney(item.price)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card payment form
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Card Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Card Number
                              TextFormField(
                                controller: _cardNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Card Number',
                                  hintText: '4242 4242 4242 4242',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.credit_card),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(16),
                                  TextInputFormatter.withFunction((
                                    oldValue,
                                    newValue,
                                  ) {
                                    final text = _formatCardNumber(
                                      newValue.text,
                                    );
                                    return TextEditingValue(
                                      text: text,
                                      selection: TextSelection.collapsed(
                                        offset: text.length,
                                      ),
                                    );
                                  }),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter card number';
                                  }

                                  final cardNumber = value.replaceAll(' ', '');
                                  if (cardNumber.length != 16) {
                                    return 'Card number must be 16 digits';
                                  }

                                  // Simple Luhn algorithm check for demo purposes
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Card Holder
                              // TextFormField(
                              //   controller: _cardHolderController,
                              //   decoration: const InputDecoration(
                              //     labelText: 'Card Holder Name',
                              //     hintText: 'John Doe',
                              //     border: OutlineInputBorder(),
                              //     prefixIcon: Icon(Icons.person),
                              //   ),
                              //   textCapitalization: TextCapitalization.words,
                              //   validator: (value) {
                              //     if (value == null || value.isEmpty) {
                              //       return 'Please enter card holder name';
                              //     }
                              //     return null;
                              //   },
                              // ),

                              // const SizedBox(height: 16),

                              // Expiry Date and CVV in row
                              Row(
                                children: [
                                  // Expiry Date
                                  Expanded(
                                    child: TextFormField(
                                      controller: _expiryDateController,
                                      decoration: const InputDecoration(
                                        labelText: 'Expiry Date',
                                        hintText: 'MM/YY',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                        TextInputFormatter.withFunction((
                                          oldValue,
                                          newValue,
                                        ) {
                                          final text = _formatExpiryDate(
                                            newValue.text,
                                          );
                                          return TextEditingValue(
                                            text: text,
                                            selection: TextSelection.collapsed(
                                              offset: text.length,
                                            ),
                                          );
                                        }),
                                      ],
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter expiry date';
                                        }

                                        final parts = value.split('/');
                                        if (parts.length != 2) {
                                          return 'Invalid format';
                                        }

                                        int? month = int.tryParse(parts[0]);
                                        if (month == null ||
                                            month < 1 ||
                                            month > 12) {
                                          return 'Invalid month';
                                        }

                                        int? year = int.tryParse(parts[1]);
                                        if (year == null) {
                                          return 'Invalid year';
                                        }

                                        // Current year last two digits
                                        final currentYear =
                                            DateTime.now().year % 100;
                                        final currentMonth =
                                            DateTime.now().month;

                                        if (year < currentYear ||
                                            (year == currentYear &&
                                                month < currentMonth)) {
                                          return 'Card expired';
                                        }

                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // CVV
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cvvController,
                                      decoration: const InputDecoration(
                                        labelText: 'CVV',
                                        hintText: '123',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.security),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      obscureText: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter CVV';
                                        }

                                        if (value.length < 3 ||
                                            value.length > 4) {
                                          return 'Invalid CVV';
                                        }

                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // // Secure payment info
                              // Container(
                              //   padding: const EdgeInsets.all(12),
                              //   decoration: BoxDecoration(
                              //     color: Colors.grey[100],
                              //     borderRadius: BorderRadius.circular(8),
                              //   ),
                              //   child: const Row(
                              //     children: [
                              //       Icon(Icons.lock, color: Colors.green),
                              //       SizedBox(width: 8),
                              //       Expanded(
                              //         child: Text(
                              //           'Your payment information is encrypted and secure.',
                              //           style: TextStyle(fontSize: 12),
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processCardPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child:
                _isProcessing
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
