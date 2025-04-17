import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/item_controller.dart';

// Provider for the ItemController
final itemControllerProvider = Provider<ItemController>((ref) {
  return ItemController();
});

// Provider for the create item function
final createItemProvider = FutureProvider.family<String, Map<String, dynamic>>((ref, itemData) async {
  final itemController = ref.read(itemControllerProvider);
  
  return itemController.createItem(
    sellerId: itemData['sellerId'] as String,
    title: itemData['title'] as String,
    description: itemData['description'] as String,
    category: itemData['category'] as String,
    originalPrice: itemData['originalPrice'] as double,
    price: itemData['price'] as double,
    imageFiles: itemData['imageFiles'] as List<File>,
  );
});

// Provider for getting an item by ID
final itemByIdProvider = FutureProvider.family<dynamic, String>((ref, itemId) async {
  final itemController = ref.read(itemControllerProvider);
  
  return itemController.getItemById(itemId);
}); 