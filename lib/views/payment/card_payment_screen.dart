import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/payment_controller.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/stripe_service.dart';
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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
    Future.microtask(() => ref.refresh(itemByIdProvider(widget.itemId)));
  }

  void _processCardPayment() async {
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

        try {
          // Price is already in cents from backend, convert to int for Stripe
          final int amountCents = item.price.toInt();

          // Show Stripe payment sheet
          final stripeSuccess = await StripeService.presentPaymentSheet(
            context,
            amountCents,
            'myr',
          );

          if (stripeSuccess) {
            // Process payment in your system after successful Stripe payment
            final paymentController = ref.read(paymentControllerProvider);
            final success = await paymentController.processCardPayment(
              buyer: buyer,
              seller: sellerAsync,
              item: item,
              paymentDetails: {
                'paymentMethod': 'stripe',
                'stripePaymentStatus': 'succeeded',
                'amount': item.price,
              },
              paymentMethod: widget.paymentData['paymentMethod'],
              deliveryAddress: widget.paymentData['deliveryAddress'],
            );

            if (success) {
              // Navigate to success screen with original data structure
              if (mounted) {
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
          } else {
            // Stripe payment was canceled or failed
            _showErrorDialog('Payment was canceled or failed. Please try again.');
          }
        } catch (e) {
          _showErrorDialog('Payment failed: ${e.toString()}');
        } finally {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        error: (error, stack) => Center(child: Text('Error: ${error.toString()}')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return itemAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: ${error.toString()}')),
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
                              'RM${formatMoney(item.price)}', // Convert cents to ringgit for display
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

                    // Payment method info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  color: Theme.of(context).primaryColor,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Credit/Debit Card',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Secure payment powered by Stripe',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stripe payment info
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'How it works',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Tap "Pay Now" to open the secure payment form\n'
                              '• Enter your card details safely\n'
                              '• Complete the payment process\n'
                              '• Your order will be confirmed automatically',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Security info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Your payment is secured with bank-level encryption',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Test mode notice (remove in production)
                    // Container(
                    //   padding: const EdgeInsets.all(12),
                    //   decoration: BoxDecoration(
                    //     color: Colors.orange.shade50,
                    //     borderRadius: BorderRadius.circular(8),
                    //     border: Border.all(color: Colors.orange.shade200),
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Icon(Icons.warning_amber, color: Colors.orange.shade600),
                    //       const SizedBox(width: 8),
                    //       const Expanded(
                    //         child: Text(
                    //           'Test Mode: Use card 4242 4242 4242 4242 with any future date and CVC',
                    //           style: TextStyle(fontSize: 12),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
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
            child: _isProcessing
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