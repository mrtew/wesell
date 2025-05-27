import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wesell/providers/item_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  final Map<String, dynamic> paymentData;
  
  const PaymentSuccessScreen({
    required this.paymentData,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extract all payment data directly from the passed map
    final int transactionAmount = paymentData['transactionAmount'] ?? 0;
    final String title = paymentData['title'] ?? 'Item';
    final String sellerId = paymentData['sellerId'] ?? '';
    // No need to fetch the item by ID, which could cause 'item not found' error
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Payment Successful',
        showBackButton: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green[700],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Success message
              const Text(
                'Payment Successful!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Your payment of RM${formatMoney(transactionAmount)} for "$title" has been completed successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'The seller has been notified about your purchase, and you can view your item in your purchased items.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              
              // sellerId.isNotEmpty ? Padding(
              //   padding: const EdgeInsets.only(top: 8.0),
              //   child: TextButton(
              //     onPressed: () {
              //       // Navigate to chat with the seller
              //       GoRouter.of(context).go('/chat');
              //       GoRouter.of(context).push('/chat/new/$sellerId');
              //     },
              //     child: const Text('Contact Seller'),
              //   ),
              // ) : const SizedBox.shrink(),
              
              const SizedBox(height: 48),
              
              // View purchased items button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to purchased items screen
                    GoRouter.of(context).go('/me');
                    GoRouter.of(context).push('/items_purchased');
                    ref.read(userPurchasedItemsProvider.notifier).refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'View Items Purchased',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              sellerId.isNotEmpty ? SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    GoRouter.of(context).go('/chat');
                    GoRouter.of(context).push('/chat/new/$sellerId');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                  child: const Text(
                    'Contact Seller',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ) : const SizedBox.shrink(),

              // Go home button
              // SizedBox(
              //   width: double.infinity,
              //   child: OutlinedButton(
              //     onPressed: () {
              //       // Navigate back to home screen
              //       GoRouter.of(context).go('/home');
              //     },
              //     style: OutlinedButton.styleFrom(
              //       padding: const EdgeInsets.symmetric(vertical: 16),
              //       side: BorderSide(color: Theme.of(context).primaryColor),
              //     ),
              //     child: const Text(
              //       'Continue Shopping',
              //       style: TextStyle(
              //         fontSize: 16,
              //         fontWeight: FontWeight.bold,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
