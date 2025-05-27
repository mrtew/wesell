import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/payment_controller.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';

class VerifyPinScreen extends ConsumerStatefulWidget {
  final String itemId;
  final Map<String, dynamic> paymentData;

  const VerifyPinScreen({
    required this.itemId,
    required this.paymentData,
    super.key,
  });

  @override
  ConsumerState<VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends ConsumerState<VerifyPinScreen> {
  // Single controller for the hidden input field
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _pin = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
    Future.microtask(() => ref.refresh(itemByIdProvider(widget.itemId)));

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

      // Verify PIN when 6 digits are entered
      if (_pin.length == 6 && !_isProcessing) {
        _verifyPin();
      }
    });
  }

  void _verifyPin() async {
    setState(() {
      _isProcessing = true;
    });

    final userAsync = ref.read(currentUserProvider);
    final itemAsync = ref.read(itemByIdProvider(widget.itemId));

    userAsync.whenData((buyer) async {
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

        // Verify PIN
        final paymentController = ref.read(paymentControllerProvider);
        if (!paymentController.verifyPin(buyer, _pin)) {
          _showErrorDialog('Incorrect PIN. Please try again.');
          // Clear PIN input
          _pinController.clear();
          setState(() {
            _pin = '';
            _isProcessing = false;
          });
          return;
        }

        // Process payment
        final success = await paymentController.processWalletPayment(
          buyer: buyer,
          seller: sellerAsync,
          item: item,
          paymentMethod: widget.paymentData['paymentMethod'],
          deliveryAddress: widget.paymentData['deliveryAddress'],
        );

        if (success) {
          // Navigate to success screen
          if (mounted) {
            // // Remove all previous screens from the navigation stack
            // GoRouter.of(context).pop(); // Remove PIN screen
            // GoRouter.of(context).pop(); // Remove address confirm screen
            // GoRouter.of(context).pop(); // Remove payment method screen

            // Go to success screen with all necessary data
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
          _showErrorDialog('Payment failed. Please try again later.');
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
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));

    return Scaffold(
      appBar: const AppBarWidget(title: 'Enter PIN', showBackButton: true),
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Item not found'));
          }

          return GestureDetector(
            // Refocus on the hidden field if user taps anywhere
            onTap: () => FocusScope.of(context).requestFocus(_focusNode),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Amount: RM${formatMoney(item.price)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),

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
                              color:
                                  isFilled
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                              width: isFilled ? 2 : 1.5,
                            ),
                            color: Colors.grey.shade100,
                          ),
                          alignment: Alignment.center,
                          child:
                              isFilled
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

                    const SizedBox(height: 32),

                    if (_isProcessing)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Processing payment...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
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
                          enabled: !_isProcessing,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(child: Text('Error: ${error.toString()}')),
      ),
    );
  }
}
