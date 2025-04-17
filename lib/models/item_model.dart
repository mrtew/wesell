import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String? itemId;
  final String sellerId;
  final String title;
  final String description;
  final String category;
  final int originalPrice; // Stored as integer (cents/pennies)
  final int price; // Stored as integer (cents/pennies)
  final List<String> images;
  final String status; // 'available', 'sold', etc.
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final Timestamp? deletedAt;
  final Map<String, dynamic>? imageMetadata; // For future image search feature

  ItemModel({
    this.itemId,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.category,
    required this.originalPrice,
    required this.price,
    required this.images,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.imageMetadata,
  });

  // Factory constructor to create an ItemModel from a Firebase document
  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ItemModel(
      itemId: doc.id,
      sellerId: data['sellerId'],
      title: data['title'],
      description: data['description'],
      category: data['category'],
      originalPrice: data['originalPrice'],
      price: data['price'],
      images: List<String>.from(data['images']),
      status: data['status'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      deletedAt: data['deletedAt'],
      imageMetadata: data['imageMetadata'],
    );
  }

  // Convert ItemModel to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'category': category,
      'originalPrice': originalPrice,
      'price': price,
      'images': images,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'imageMetadata': imageMetadata,
    };
  }

  // Create a copy of the current item with updated fields
  ItemModel copyWith({
    String? itemId,
    String? sellerId,
    String? title,
    String? description,
    String? category,
    int? originalPrice,
    int? price,
    List<String>? images,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? deletedAt,
    Map<String, dynamic>? imageMetadata,
  }) {
    return ItemModel(
      itemId: itemId ?? this.itemId,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      originalPrice: originalPrice ?? this.originalPrice,
      price: price ?? this.price,
      images: images ?? this.images,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      imageMetadata: imageMetadata ?? this.imageMetadata,
    );
  }
} 