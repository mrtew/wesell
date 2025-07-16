import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/top_up_sheet.dart';

class BalanceScreen extends ConsumerStatefulWidget {
  const BalanceScreen({super.key});

  @override
  ConsumerState<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends ConsumerState<BalanceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
  }

  void _showTopUpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TopUpSheet(
          onTopUpComplete: () {
            // Refresh user data to update balance
            Future.microtask(() => ref.refresh(currentUserProvider));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBarWidget(
        title: 'Wallet',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              GoRouter.of(context).push('/transaction_history');
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: ${error.toString()}')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          
          // User balance is stored in cents, formatMoney converts to RM format
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.currency_exchange_rounded, color: Colors.yellow[600], size: 64,),
                const SizedBox(height: 40),
                const Text(
                  'My Balance',
                  style: TextStyle(
                    fontSize: 24,
                    // fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'RM${formatMoney(user.balance)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _showTopUpSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Top Up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).push('/old_pin');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Change PIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 