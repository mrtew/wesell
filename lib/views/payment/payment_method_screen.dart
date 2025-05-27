import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../models/item_model.dart';
import '../../models/user_model.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  final String itemId;
  
  const PaymentMethodScreen({
    required this.itemId,
    super.key,
  });

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
    Future.microtask(() => ref.refresh(itemByIdProvider(widget.itemId)));
  }

  void _checkUserAddressAndProceed(String paymentMethod) {
    final userAsync = ref.read(currentUserProvider);
    
    userAsync.when(
      data: (user) {
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
          return;
        }
        
        // Check if user has at least one address
        if (user.addresses.isEmpty) {
          _showNoAddressDialog();
          return;
        }
        
        // Proceed to address confirmation
        GoRouter.of(context).push(
          '/payment/${widget.itemId}/address_confirm',
          extra: paymentMethod
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error.toString()}')),
        );
      },
    );
  }

  void _showNoAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Address Required'),
        content: const Text(
          'You need a delivery address before making a purchase. Please add your address in your account.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          // ElevatedButton(
          //   onPressed: () {
          //     Navigator.of(context).pop();
          //     GoRouter.of(context).push('/addresses');
          //   },
          //   // style: ElevatedButton.styleFrom(
          //   //   backgroundColor: Theme.of(context).primaryColor,
          //   // ),
          //   child: const Text('Add Address'),
          // ),
        ],
      ),
    );
  }

  void _checkWalletStatusAndProceed(UserModel user, ItemModel item) {
    // Check if wallet is activated (PIN is set)
    if (user.pin.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Wallet Not Activated'),
          content: const Text(
            'Your wallet is not activated yet. Please activate it in your account.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Check if wallet has sufficient balance
    if (user.balance < item.price) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient Balance'),
          content: Text(
            'Your wallet balance is insufficient to make this purchase.\n\n'
            'Current balance: RM${formatMoney(user.balance)}\n'
            'Required amount: RM${formatMoney(item.price)}'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    // If all checks pass, proceed to address confirmation
    _checkUserAddressAndProceed('wallet');
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Payment Method',
        showBackButton: true,
      ),
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

              // Check if the user is trying to buy their own item
              if (user.uid == item.sellerId) {
                return const Center(
                  child: Text('You cannot purchase your own item'),
                );
              }

              // Check if the item is already sold
              if (item.status != 'available') {
                return const Center(
                  child: Text('This item is no longer available for purchase'),
                );
              }
              
              final formattedItemPrice = formatMoney(item.price);
              final formattedUserBalance = formatMoney(user.balance);

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount to pay:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM$formattedItemPrice',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose your payment method:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Wallet Payment Option
                    Card(
                      child: InkWell(
                        onTap: () => _checkWalletStatusAndProceed(user, item),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 36,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Wallet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (user.pin.isNotEmpty)
                                    Text(
                                      'Current Balance: RM$formattedUserBalance',
                                      style: TextStyle(
                                        color: user.balance < item.price 
                                            ? Colors.red 
                                            : Colors.green,
                                      ),
                                    ),
                                    if (user.pin.isEmpty)
                                    Text(
                                      'Not Activated',
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Card Payment Option
                    Card(
                      child: InkWell(
                        onTap: () => _checkUserAddressAndProceed('card'),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.creditCard,
                                size: 36,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Credit/Debit Card',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('Pay with Visa, Mastercard, etc.'),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    
                    // Payment Terms
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'By proceeding with the payment, you agree to our terms and conditions.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
