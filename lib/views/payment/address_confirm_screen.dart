import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/address_model.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';

class AddressConfirmScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String paymentMethod;
  
  const AddressConfirmScreen({
    required this.itemId,
    required this.paymentMethod,
    super.key,
  });

  @override
  ConsumerState<AddressConfirmScreen> createState() => _AddressConfirmScreenState();
}

class _AddressConfirmScreenState extends ConsumerState<AddressConfirmScreen> {
  int _selectedAddressIndex = -1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Refresh data and wait for completion
      ref.refresh(currentUserProvider).whenData((_) {});
      ref.refresh(itemByIdProvider(widget.itemId)).whenData((_) {});
      
      // Find default address index
      final userAsync = ref.read(currentUserProvider);
      userAsync.whenData((user) {
        if (user != null && user.addresses.isNotEmpty) {
          for (int i = 0; i < user.addresses.length; i++) {
            if (user.addresses[i]['isDefault'] == true) {
              setState(() {
                _selectedAddressIndex = i;
              });
              break;
            }
          }
          
          // If no default address is found, select the first one
          if (_selectedAddressIndex == -1 && user.addresses.isNotEmpty) {
            setState(() {
              _selectedAddressIndex = 0;
            });
          }
        }
      });
    });
  }

  void _proceedToPayment() {
    final userAsync = ref.read(currentUserProvider);
    
    userAsync.when(
      data: (user) {
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
          return;
        }
        
        if (_selectedAddressIndex < 0 || _selectedAddressIndex >= user.addresses.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a delivery address')),
          );
          return;
        }
        
        final selectedAddress = user.addresses[_selectedAddressIndex];
        
        // Route based on payment method
        if (widget.paymentMethod == 'wallet') {
          GoRouter.of(context).push(
            '/payment/${widget.itemId}/verify_pin',
            extra: {
              'paymentMethod': 'wallet',
              'deliveryAddress': selectedAddress,
            },
          );
        } else {
          // For card payment
          GoRouter.of(context).push(
            '/payment/${widget.itemId}/card_payment',
            extra: {
              'deliveryAddress': selectedAddress,
            },
          );
        }
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error.toString()}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Confirm Address',
        showBackButton: true,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: ${error.toString()}')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          if (user.addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('You don\'t have any addresses yet'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => GoRouter.of(context).push('/addresses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: const Text('Add Address'),
                  ),
                ],
              ),
            );
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
                    // Item and payment info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      // fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'RM${formatMoney(item.price)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Payment Method: ',
                                    // style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.paymentMethod.substring(0, 1).toUpperCase() + 
                                  widget.paymentMethod.substring(1),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Delivery address selection
                    const Text(
                      'Select Delivery Address',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: user.addresses.length,
                        itemBuilder: (context, index) {
                          final address = AddressModel.fromMap(
                            user.addresses[index], 
                            index.toString(),
                          );
                          
                          final bool isDefault = user.addresses[index]['isDefault'] == true;
                          
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _selectedAddressIndex == index
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedAddressIndex = index;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Radio<int>(
                                          value: index,
                                          groupValue: _selectedAddressIndex,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedAddressIndex = value!;
                                            });
                                          },
                                        ),
                                        Text(
                                          address.recipientName ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // if (isDefault)
                                        //   Container(
                                        //     padding: const EdgeInsets.symmetric(
                                        //       horizontal: 8,
                                        //       vertical: 2,
                                        //     ),
                                        //     decoration: BoxDecoration(
                                        //       color: Colors.green,
                                        //       borderRadius: BorderRadius.circular(4),
                                        //     ),
                                        //     child: const Text(
                                        //       'Default',
                                        //       style: TextStyle(
                                        //         fontSize: 12,
                                        //         color: Colors.white,
                                        //       ),
                                        //     ),
                                        //   ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 48.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            address.recipientPhone ?? '',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            address.fullAddress,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    // Row(
                    //   children: [
                    //     TextButton.icon(
                    //       onPressed: () => GoRouter.of(context).push('/addresses'),
                    //       icon: const Icon(Icons.add),
                    //       label: const Text('Add New Address'),
                    //     ),
                    //   ],
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
          child: ElevatedButton(
            onPressed: _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Confirm and Continue',
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
