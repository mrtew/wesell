import 'package:cloud_firestore/cloud_firestore.dart';

class SellerModel {
  final String id; // Firestore document ID
  final String userId;
  final Timestamp createdAt;

  SellerModel({
    required this.id,
    required this.userId,
    required this.createdAt,
  });

  // Factory constructor to create a SellerModel from a Firebase document
  factory SellerModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SellerModel(
      id: doc.id,
      userId: data['userId'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert SellerModel to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'createdAt': createdAt,
    };
  }
}
