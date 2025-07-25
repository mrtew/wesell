import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction_model.dart';

// Provider for TransactionController
final transactionControllerProvider = Provider<TransactionController>((ref) {
  return TransactionController();
});

// Provider for user transactions (using the method without index requirements)
final userTransactionsProvider = FutureProvider.family<List<TransactionModel>, String>((ref, userId) async {
  final transactionController = ref.watch(transactionControllerProvider);
  // return await transactionController.getUserTransactions(userId);
  return await transactionController.getUserTransactionsWithIndex(userId);
});

// Provider for user transactions with index (for better performance if indexes are set up)
final userTransactionsWithIndexProvider = FutureProvider.family<List<TransactionModel>, String>((ref, userId) async {
  final transactionController = ref.watch(transactionControllerProvider);
  return await transactionController.getUserTransactionsWithIndex(userId);
});

// State provider for transaction processing
final transactionProcessingProvider = StateProvider<bool>((ref) => false);

// State provider for transaction error
final transactionErrorProvider = StateProvider<String?>((ref) => null);