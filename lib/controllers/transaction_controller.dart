import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class TransactionController {
  final CollectionReference _transactionsCollection = FirebaseFirestore.instance.collection('transactions');
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Create a new transaction
  Future<String> createTransaction(TransactionModel transaction) async {
    DocumentReference docRef = await _transactionsCollection.add(transaction.toMap());
    return docRef.id;
  }

  // Get transaction by ID
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    try {
      DocumentSnapshot doc = await _transactionsCollection.doc(transactionId).get();
      if (doc.exists) {
        return TransactionModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get all transactions for a user (buyer, seller, or top-up)
  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    try {
      List<TransactionModel> allTransactions = [];
      
      // Get transactions where user is buyer
      QuerySnapshot buyerTransactions = await _transactionsCollection
          .where('buyerId', isEqualTo: userId)
          .get();
      
      // Get transactions where user is seller
      QuerySnapshot sellerTransactions = await _transactionsCollection
          .where('sellerId', isEqualTo: userId)
          .get();
      
      // Add buyer transactions
      for (var doc in buyerTransactions.docs) {
        allTransactions.add(TransactionModel.fromFirestore(doc));
      }
      
      // Add seller transactions (avoid duplicates)
      for (var doc in sellerTransactions.docs) {
        if (!allTransactions.any((t) => t.id == doc.id)) {
          allTransactions.add(TransactionModel.fromFirestore(doc));
        }
      }
      
      // Sort by createdAt in descending order
      allTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return allTransactions;
    } catch (e) {
      rethrow;
    }
  }

  // Alternative method using a single query (requires composite index)
  Future<List<TransactionModel>> getUserTransactionsWithIndex(String userId) async {
    try {
      // This approach requires composite indexes for both buyerId+createdAt and sellerId+createdAt
      List<TransactionModel> allTransactions = [];
      
      // Get transactions where user is buyer
      QuerySnapshot buyerTransactions = await _transactionsCollection
          .where('buyerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      // Get transactions where user is seller
      QuerySnapshot sellerTransactions = await _transactionsCollection
          .where('sellerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      // Combine and sort
      allTransactions.addAll(buyerTransactions.docs.map((doc) => TransactionModel.fromFirestore(doc)));
      allTransactions.addAll(sellerTransactions.docs.map((doc) => TransactionModel.fromFirestore(doc)));
      
      // Remove duplicates and sort
      final uniqueTransactions = <String, TransactionModel>{};
      for (var transaction in allTransactions) {
        uniqueTransactions[transaction.id] = transaction;
      }
      
      final result = uniqueTransactions.values.toList();
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Update transaction status
  Future<void> updateTransactionStatus(String transactionId, String status) async {
    await _transactionsCollection.doc(transactionId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  // Process top-up transaction
  // Amount is in cents (1 RM = 100 cents)
  Future<bool> processTopUp(String userId, int amountCents, Map<String, dynamic> paymentDetails) async {
    try {
      // Create transaction in Firestore
      Timestamp now = Timestamp.now();
      TransactionModel transaction = TransactionModel(
        id: '',
        buyerId: userId,
        sellerId: '',
        itemId: '',
        type: 'topup',
        amount: amountCents,
        description: 'Wallet top-up',
        paymentMethod: paymentDetails['paymentMethod'] ?? 'card',
        status: 'completed', // For simulation purposes
        paymentDetails: paymentDetails,
        createdAt: now,
        updatedAt: now,
      );
      
      String transactionId = await createTransaction(transaction);
      
      // Get user document
      DocumentSnapshot userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        return false;
      }
      
      // Update user balance - balance is stored in cents
      UserModel user = UserModel.fromFirestore(userDoc);
      int newBalance = user.balance + amountCents;
      
      // Add transaction ID to user's transactions list
      List<String> updatedTransactions = List<String>.from(user.transactions);
      updatedTransactions.add(transactionId);
      
      // Update user document
      await _usersCollection.doc(userId).update({
        'balance': newBalance,
        'transactions': updatedTransactions,
        'updatedAt': now,
      });
      
      return true;
    } catch (e) {
      print('Error processing top-up: $e');
      return false;
    }
  }
}