import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh transactions every time this page is pushed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user != null) {
        ref.refresh(userTransactionsProvider(user.uid));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Transaction History',
        showBackButton: true,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final userTransactionsAsync = ref.watch(userTransactionsProvider(user.uid));

          return userTransactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error loading transactions: ${error.toString()}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(userTransactionsProvider(user.uid)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (transactions) {
              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Transactions Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your transaction history will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // ElevatedButton.icon(
                      //   onPressed: () => GoRouter.of(context).go('/balance'),
                      //   icon: const Icon(Icons.add_card, color: Colors.white),
                      //   label: const Text('Top Up Wallet', style: TextStyle(color: Colors.white)),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.blue,
                      //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.refresh(userTransactionsProvider(user.uid));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionCard(transaction, user.uid);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction, String currentUserId) {
    // Determine if this is income or expense for current user
    bool isIncome = _isIncomeTransaction(transaction, currentUserId);
    Color amountColor = isIncome ? Colors.green[600]! : Colors.red[600]!;
    IconData transactionIcon = _getTransactionIcon(transaction);
    Color iconColor = _getIconColor(transaction, isIncome);
    String amountText = _getAmountText(transaction, isIncome);
    String subtitle = _getTransactionSubtitle(transaction, currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        // leading: Container(
        //   padding: const EdgeInsets.all(12),
        //   decoration: BoxDecoration(
        //     color: iconColor.withOpacity(0.1),
        //     borderRadius: BorderRadius.circular(12),
        //   ),
        //   child: Icon(
        //     transactionIcon,
        //     color: iconColor,
        //     size: 24,
        //   ),
        // ),
        title: Text(
          transaction.description,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTransactionDate(transaction.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 6),
            _buildStatusChip(transaction.status),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              amountText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              transaction.paymentMethod.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isIncomeTransaction(TransactionModel transaction, String currentUserId) {
    switch (transaction.type) {
      case 'topup':
        return true; // Top-up always increases user balance
      case 'purchase':
        return transaction.sellerId == currentUserId; // User receives money as seller
      case 'refund':
        return transaction.buyerId == currentUserId; // User receives refund as buyer
      default:
        return false;
    }
  }

  IconData _getTransactionIcon(TransactionModel transaction) {
    switch (transaction.type) {
      case 'topup':
        return Icons.add_circle_outline;
      case 'purchase':
        return Icons.shopping_bag_outlined;
      case 'refund':
        return Icons.refresh_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Color _getIconColor(TransactionModel transaction, bool isIncome) {
    switch (transaction.type) {
      case 'topup':
        return Colors.blue[600]!;
      case 'purchase':
        return isIncome ? Colors.green[600]! : Colors.orange[600]!;
      case 'refund':
        return Colors.purple[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getAmountText(TransactionModel transaction, bool isIncome) {
    String sign = isIncome ? '+' : '-';
    return '$sign RM${formatMoney(transaction.amount)}';
  }

  String _getTransactionSubtitle(TransactionModel transaction, String currentUserId) {
    switch (transaction.type) {
      case 'topup':
        return 'Wallet Top-up';
      case 'purchase':
        if (transaction.sellerId == currentUserId) {
          return 'Item Sale'; // User is the seller
        } else {
          return 'Item Purchase'; // User is the buyer
        }
      case 'refund':
        return 'Payment Refund';
      default:
        return transaction.type.toUpperCase();
    }
  }

  String _formatTransactionDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else {
      date = timestamp.toDate();
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, HH:mm').format(date);
    } else {
      return DateFormat('MMM d, yyyy HH:mm').format(date);
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        break;
      case 'pending':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        break;
      case 'failed':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}