import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String userId;
  final String role;
  final String username;
  final String avatar;
  final String phoneNumber;
  final String email;
  final Map<String, String> identity;
  final bool isPhoneNumberVerified;
  final bool isEmailVerified;
  final bool isIdentityVerified;
  final List<Map<String, dynamic>> addresses;
  final List<String> itemsPosted;
  final List<String> itemsPurchased;
  final List<String> itemsSold;
  final List<String> chats;
  final List<String> transactions;
  final int balance;
  final String pin;
  final String? fcmToken;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? deletedAt;

  UserModel({
    required this.uid,
    required this.userId,
    required this.role,
    required this.username,
    required this.avatar,
    required this.phoneNumber,
    required this.email,
    required this.identity,
    required this.isPhoneNumberVerified,
    required this.isEmailVerified,
    required this.isIdentityVerified,
    required this.addresses,
    required this.itemsPosted,
    required this.itemsPurchased,
    required this.itemsSold,
    required this.chats,
    required this.transactions,
    required this.balance,
    required this.pin,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  // Factory constructor to create a UserModel from a Firebase document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      userId: data['userId'],
      role: data['role'],
      username: data['username'],
      avatar: data['avatar'],
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      identity: Map<String, String>.from(data['identity']),
      isPhoneNumberVerified: data['isPhoneNumberVerified'],
      isEmailVerified: data['isEmailVerified'],
      isIdentityVerified: data['isIdentityVerified'],
      addresses: List<Map<String, dynamic>>.from(data['addresses']),
      itemsPosted: List<String>.from(data['itemsPosted']),
      itemsPurchased: List<String>.from(data['itemsPurchased']),
      itemsSold: List<String>.from(data['itemsSold']),
      chats: List<String>.from(data['chats']),
      transactions: List<String>.from(data['transactions']),
      balance: data['balance'],
      pin: data['pin'],
      fcmToken: data['fcmToken'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      deletedAt: data['deletedAt'],
    );
  }

  // Convert UserModel to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role,
      'username': username,
      'avatar': avatar,
      'phoneNumber': phoneNumber,
      'email': email,
      'identity': identity,
      'isPhoneNumberVerified': isPhoneNumberVerified,
      'isEmailVerified': isEmailVerified,
      'isIdentityVerified': isIdentityVerified,
      'addresses': addresses,
      'itemsPosted': itemsPosted,
      'itemsPurchased': itemsPurchased,
      'itemsSold': itemsSold,
      'chats': chats,
      'transactions': transactions,
      'balance': balance,
      'pin': pin,
      'fcmToken': fcmToken,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  // Create a copy of the current user with updated fields
  UserModel copyWith({
    String? uid,
    String? userId,
    String? role,
    String? username,
    String? avatar,
    String? phoneNumber,
    String? email,
    Map<String, String>? identity,
    bool? isPhoneNumberVerified,
    bool? isEmailVerified,
    bool? isIdentityVerified,
    List<Map<String, dynamic>>? addresses,
    List<String>? itemsPosted,
    List<String>? itemsPurchased,
    List<String>? itemsSold,
    List<String>? chats,
    List<String>? transactions,
    int? balance,
    String? pin,
    String? fcmToken,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? deletedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      identity: identity ?? this.identity,
      isPhoneNumberVerified: isPhoneNumberVerified ?? this.isPhoneNumberVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      addresses: addresses ?? this.addresses,
      itemsPosted: itemsPosted ?? this.itemsPosted,
      itemsPurchased: itemsPurchased ?? this.itemsPurchased,
      itemsSold: itemsSold ?? this.itemsSold,
      chats: chats ?? this.chats,
      transactions: transactions ?? this.transactions,
      balance: balance ?? this.balance,
      pin: pin ?? this.pin,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
} 