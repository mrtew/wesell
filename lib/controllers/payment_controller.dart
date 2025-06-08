import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';
import '../providers/item_provider.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';

final paymentControllerProvider = Provider<PaymentController>((ref) {
  return PaymentController(ref);
});

class PaymentController {
  final ProviderRef ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  PaymentController(this.ref);

  // Check if user has activated their wallet
  bool isWalletActivated(UserModel user) {
    return user.pin.isNotEmpty;
  }

  // Check if user has sufficient balance for the purchase
  bool hasSufficientBalance(UserModel user, int amount) {
    return user.balance >= amount;
  }

  // Verify PIN against user's saved PIN
  bool verifyPin(UserModel user, String enteredPin) {
    return user.pin == enteredPin;
  }

  // Process wallet payment
  Future<bool> processWalletPayment({
    required UserModel buyer,
    required UserModel seller,
    required ItemModel item,
    required String paymentMethod,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    final batch = _firestore.batch();
    final timestamp = Timestamp.now();

    try {
      // Create transaction record with Firestore auto-generated ID
      final transactionRef = _firestore.collection('transactions').doc();
      final transactionId = transactionRef.id;
      final transactionData = {
        'buyerId': buyer.uid,
        'sellerId': seller.uid,
        'itemId': item.itemId,
        'type': 'purchase',
        'amount': item.price,
        'description': 'Payment for ${item.title}',
        'paymentMethod': paymentMethod,
        'status': 'completed',
        'paymentDetails': {'deliveryAddress': deliveryAddress},
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      batch.set(transactionRef, transactionData);

      // Update item status to sold
      final itemRef = _firestore.collection('items').doc(item.itemId);
      batch.update(itemRef, {'status': 'sold', 'updatedAt': timestamp});

      // Update buyer (subtract balance, add to purchased items, add transaction)
      final buyerItemsPurchased = List<String>.from(buyer.itemsPurchased);
      buyerItemsPurchased.add(item.itemId!);

      final buyerTransactions = List<String>.from(buyer.transactions);
      buyerTransactions.add(transactionId);

      final buyerRef = _firestore.collection('users').doc(buyer.uid);
      batch.update(buyerRef, {
        'balance': FieldValue.increment(-item.price),
        'itemsPurchased': buyerItemsPurchased,
        'transactions': buyerTransactions,
        'updatedAt': timestamp,
      });

      // Update seller (add balance, add to sold items, add transaction)
      final sellerItemsSold = List<String>.from(seller.itemsSold);
      sellerItemsSold.add(item.itemId!);

      final sellerTransactions = List<String>.from(seller.transactions);
      sellerTransactions.add(transactionId);

      final sellerRef = _firestore.collection('users').doc(seller.uid);
      batch.update(sellerRef, {
        'balance': FieldValue.increment(item.price),
        'itemsSold': sellerItemsSold,
        'transactions': sellerTransactions,
        'updatedAt': timestamp,
      });

      // Commit all changes in the batch first
      await batch.commit();

      // After batch completes, update or create chat
      final chatId = await _addPostPurchaseMessage(
        buyer,
        seller,
        item,
        transactionId,
        timestamp,
        deliveryAddress,
      );

      // Send notifications
      await _sendPaymentNotifications(
        buyer: buyer,
        seller: seller,
        item: item,
        transactionId: transactionId,
        chatId: chatId,
      );

      // Refresh provider states
      ref.invalidate(currentUserProvider);
      ref.invalidate(itemByIdProvider(item.itemId!));
      ref.invalidate(sellerByIdProvider(seller.uid));

      return true;
    } catch (e) {
      debugPrint('Error processing wallet payment: $e');
      return false;
    }
  }

  // Process card payment via Stripe
  Future<bool> processCardPayment({
    required UserModel buyer,
    required UserModel seller,
    required ItemModel item,
    required Map<String, dynamic> paymentDetails,
    required String paymentMethod,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    final batch = _firestore.batch();
    final timestamp = Timestamp.now();

    try {
      // In a real-world scenario, you would handle the actual Stripe payment here
      // For simulation, we'll just create the transaction record and update the data

      // Create transaction record with Firestore auto-generated ID
      final transactionRef = _firestore.collection('transactions').doc();
      final transactionId = transactionRef.id;
      final transactionData = {
        'buyerId': buyer.uid,
        'sellerId': seller.uid,
        'itemId': item.itemId,
        'type': 'purchase',
        'amount': item.price,
        'description': 'Payment for ${item.title}',
        'paymentMethod': 'card',
        'status': 'completed',
        'paymentDetails': {
          'cardDetails': paymentDetails,
          'deliveryAddress': deliveryAddress,
        },
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      batch.set(transactionRef, transactionData);

      // Update item status to sold
      final itemRef = _firestore.collection('items').doc(item.itemId);
      batch.update(itemRef, {'status': 'sold', 'updatedAt': timestamp});

      // Update buyer (add to purchased items, add transaction)
      final buyerItemsPurchased = List<String>.from(buyer.itemsPurchased);
      buyerItemsPurchased.add(item.itemId!);

      final buyerTransactions = List<String>.from(buyer.transactions);
      buyerTransactions.add(transactionId);

      final buyerRef = _firestore.collection('users').doc(buyer.uid);
      batch.update(buyerRef, {
        'itemsPurchased': buyerItemsPurchased,
        'transactions': buyerTransactions,
        'updatedAt': timestamp,
      });

      // Update seller (add balance, add to sold items, add transaction)
      final sellerItemsSold = List<String>.from(seller.itemsSold);
      sellerItemsSold.add(item.itemId!);

      final sellerTransactions = List<String>.from(seller.transactions);
      sellerTransactions.add(transactionId);

      final sellerRef = _firestore.collection('users').doc(seller.uid);
      batch.update(sellerRef, {
        'balance': FieldValue.increment(item.price),
        'itemsSold': sellerItemsSold,
        'transactions': sellerTransactions,
        'updatedAt': timestamp,
      });

      // Commit all changes in the batch first
      await batch.commit();

      // After batch completes, update or create chat
      final chatId = await _addPostPurchaseMessage(
        buyer,
        seller,
        item,
        transactionId,
        timestamp,
        deliveryAddress,
      );

      // Send notifications
      await _sendPaymentNotifications(
        buyer: buyer,
        seller: seller,
        item: item,
        transactionId: transactionId,
        chatId: chatId,
      );

      // Refresh provider states
      ref.invalidate(currentUserProvider);
      ref.invalidate(itemByIdProvider(item.itemId!));
      ref.invalidate(sellerByIdProvider(seller.uid));

      return true;
    } catch (e) {
      debugPrint('Error processing card payment: $e');
      return false;
    }
  }

  // Send payment notifications to buyer and seller
  Future<void> _sendPaymentNotifications({
    required UserModel buyer,
    required UserModel seller,
    required ItemModel item,
    required String transactionId,
    String? chatId,
  }) async {
    try {
      debugPrint('Starting to send payment notifications...');
      debugPrint('Buyer: ${buyer.username} (${buyer.uid})');
      debugPrint('Seller: ${seller.username} (${seller.uid})');
      debugPrint('Transaction ID: $transactionId');
      
      // Format price for display
      String formattedPrice = (item.price / 100).toStringAsFixed(2);

      // Send notification to buyer
      debugPrint('Sending notification to buyer...');
      await _notificationService.sendNotification(
        userIds: [buyer.uid],
        transactionId: transactionId,
        type: 'purchase',
        title: 'Purchase Successful',
        content: 'You have successfully purchased "${item.title}" for RM$formattedPrice from ${seller.username}.',
        additionalData: {
          'sellerId': seller.uid,
          'buyerId': buyer.uid,
          'itemId': item.itemId,
        },
      );
      debugPrint('Buyer notification sent successfully');

      // Send notification to seller
      debugPrint('Sending notification to seller...');
      await _notificationService.sendNotification(
        userIds: [seller.uid],
        transactionId: transactionId,
        type: 'purchase',
        title: 'Item Sold',
        content: 'Your item "${item.title}" has been sold for RM$formattedPrice to ${buyer.username}.',
        additionalData: {
          'sellerId': seller.uid,
          'buyerId': buyer.uid,
          'itemId': item.itemId,
        },
      );
      debugPrint('Seller notification sent successfully');
      debugPrint('All payment notifications completed');
    } catch (e) {
      debugPrint('Error sending notifications: $e');
    }
  }

  // Add purchase message to existing chat or create new chat if none exists
  Future<String?> _addPostPurchaseMessage(
    UserModel buyer,
    UserModel seller,
    ItemModel item,
    String transactionId,
    Timestamp timestamp,
    Map<String, dynamic> deliveryAddress,
  ) async {
    try {
      // Check if there's an existing chat between these users
      // First check where buyer is sender and seller is receiver
      QuerySnapshot senderReceiverQuery =
          await _firestore
              .collection('chats')
              .where('userIds.sender', isEqualTo: buyer.uid)
              .where('userIds.receiver', isEqualTo: seller.uid)
              .limit(1)
              .get();

      // Then check where seller is sender and buyer is receiver
      QuerySnapshot receiverSenderQuery =
          await _firestore
              .collection('chats')
              .where('userIds.sender', isEqualTo: seller.uid)
              .where('userIds.receiver', isEqualTo: buyer.uid)
              .limit(1)
              .get();

      bool chatExists =
          senderReceiverQuery.docs.isNotEmpty ||
          receiverSenderQuery.docs.isNotEmpty;
      String chatId;

      // Format price for display
      String formattedPrice = (item.price / 100).toStringAsFixed(2);

      // Prepare post-purchase message
      final Map<String, dynamic> newMessage = {
        'senderId': buyer.uid,
        'content':
            "Hi ${seller.username}, I have bought your item '${item.title}'. Below are the details:\n\n" +
            "Transaction ID: \n$transactionId\n\n" +
            "Transaction Amount: \nRM$formattedPrice\n\n" +
            "Transaction Time: \n${timestamp.toDate().toString()}\n\n" +
            // "Buyer Name: \n${buyer.username}\n\n" +
            "Please send the item for me as soon as possible.\n\n" +
            "Recipient Name: \n${deliveryAddress['recipientName']}\n\n" +
            "Recipient Phone: \n${deliveryAddress['recipientPhone']}\n\n" +
            "Delivery Address: \n${deliveryAddress['address']}, ${deliveryAddress['city']}, ${deliveryAddress['postalCode']}, ${deliveryAddress['state']}, ${deliveryAddress['country']}\n\n" +
            "Thank You.",
        'timestamp': timestamp,
        'type': 'text',
      };

      if (chatExists) {
        // Use existing chat - just add the new message
        chatId =
            senderReceiverQuery.docs.isNotEmpty
                ? senderReceiverQuery.docs.first.id
                : receiverSenderQuery.docs.first.id;

        debugPrint('Adding message to existing chat: $chatId');

        await _firestore.collection('chats').doc(chatId).update({
          'messages': FieldValue.arrayUnion([newMessage]),
          'updatedAt': timestamp,
        });
      } else {
        // Create new chat with Firestore auto-generated ID
        final chatRef = _firestore.collection('chats').doc();
        chatId = chatRef.id;
        debugPrint('Creating new chat: $chatId');

        // Add chat ID to both users' chats lists
        final buyerChats = List<String>.from(buyer.chats);
        buyerChats.add(chatId);
        await _firestore.collection('users').doc(buyer.uid).update({
          'chats': buyerChats,
        });

        final sellerChats = List<String>.from(seller.chats);
        sellerChats.add(chatId);
        await _firestore.collection('users').doc(seller.uid).update({
          'chats': sellerChats,
        });

        // Create the new chat with the purchase message and correct userIds structure
        await chatRef.set({
          'userIds': {
            'sender': buyer.uid, // Buyer is the sender of the first message
            'receiver': seller.uid, // Seller is the receiver
          },
          'messages': [newMessage],
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
      }

      return chatId;
    } catch (e) {
      debugPrint('Error creating or updating chat: $e');
      return null;
    }
  }
}
