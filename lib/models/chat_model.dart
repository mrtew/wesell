import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatModel {
  final String id;
  final Map<String, dynamic> userIds; // Contains sender and receiver
  final List<Map<String, dynamic>> messages; // Type, content, timestamp
  final Timestamp createdAt;
  final Timestamp updatedAt;

  ChatModel({
    required this.id,
    required this.userIds,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a ChatModel from a Firebase document
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Handle messages list safely
      List<Map<String, dynamic>> messagesList = [];
      if (data['messages'] != null) {
        try {
          messagesList = List<Map<String, dynamic>>.from(data['messages']);
        } catch (e) {
          debugPrint('Error parsing messages: $e');
        }
      }
      
      return ChatModel(
        id: doc.id,
        userIds: data['userIds'] ?? {},
        messages: messagesList,
        createdAt: data['createdAt'] ?? Timestamp.now(),
        updatedAt: data['updatedAt'] ?? Timestamp.now(),
      );
    } catch (e) {
      debugPrint('Error creating ChatModel from Firestore document: $e');
      // Return an empty chat model rather than throwing
      return ChatModel(
        id: doc.id,
        userIds: {},
        messages: [],
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
    }
  }

  // Convert ChatModel to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userIds': userIds,
      'messages': messages,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create a copy of the current chat with updated fields
  ChatModel copyWith({
    String? id,
    Map<String, dynamic>? userIds,
    List<Map<String, dynamic>>? messages,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userIds: userIds ?? this.userIds,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 