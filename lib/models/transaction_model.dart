import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String itemId;
  final String type; // 'topup', 'purchase', 'refund', etc.
  final int amount;
  final String description;
  final String paymentMethod; // 'card', 'bank_transfer', etc.
  final String status; // 'pending', 'completed', 'failed'
  final Map<String, dynamic> paymentDetails;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  TransactionModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.itemId,
    required this.type,
    required this.amount,
    required this.description,
    required this.paymentMethod,
    required this.status,
    required this.paymentDetails,
    required this.createdAt,
    this.updatedAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      buyerId: data['buyerId'],
      sellerId: data['sellerId'],
      itemId: data['itemId'],
      type: data['type'],
      amount: data['amount'],
      description: data['description'],
      paymentMethod: data['paymentMethod'],
      status: data['status'],
      paymentDetails: data['paymentDetails'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'itemId': itemId,
      'type': type,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'status': status,
      'paymentDetails': paymentDetails,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
} 