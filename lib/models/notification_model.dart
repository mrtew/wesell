import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? notificationId;
  final List<String> userIds;
  final String transactionId;
  final String type;
  final String title;
  final String content;
  final Timestamp createdAt;

  NotificationModel({
    this.notificationId,
    required this.userIds,
    required this.transactionId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  // Factory constructor to create a NotificationModel from a Firebase document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      userIds: List<String>.from(data['userIds'] ?? []),
      transactionId: data['transactionId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  // Convert NotificationModel to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userIds': userIds,
      'transactionId': transactionId,
      'type': type,
      'title': title,
      'content': content,
      'createdAt': createdAt,
    };
  }

  // Create a copy of the current notification with updated fields
  NotificationModel copyWith({
    String? notificationId,
    List<String>? userIds,
    String? transactionId,
    String? type,
    String? title,
    String? content,
    Timestamp? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userIds: userIds ?? this.userIds,
      transactionId: transactionId ?? this.transactionId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 