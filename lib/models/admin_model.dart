import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String uid;
  final String username;
  final String password;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  AdminModel({
    required this.uid,
    required this.username,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create an AdminModel from a Firebase document
  factory AdminModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AdminModel(
      uid: doc.id,
      username: data['username'],
      password: data['password'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  // Convert AdminModel to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}