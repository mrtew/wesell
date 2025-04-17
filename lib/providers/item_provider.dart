import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/item_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

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

// Provider for home page items with pagination
final homeItemsProvider = StateNotifierProvider<HomeItemsNotifier, AsyncValue<List<ItemModel>>>((ref) {
  return HomeItemsNotifier(ref);
});

class HomeItemsNotifier extends StateNotifier<AsyncValue<List<ItemModel>>> {
  final Ref _ref;
  final int _pageSize = 10;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  bool _isInitialized = false;

  HomeItemsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadInitialItems();
  }

  Future<void> loadInitialItems() async {
    if (_isInitialized && state is! AsyncLoading) {
      // Don't reload if already initialized and not in loading state
      return;
    }
    
    try {
      state = const AsyncValue.loading();
      _lastDocument = null;
      _hasMore = true;
      final items = await _fetchItems();
      state = AsyncValue.data(items);
      _isInitialized = true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> loadMoreItems() async {
    if (!_hasMore || state.isLoading) return;

    try {
      final currentItems = state.value ?? [];
      final newItems = await _fetchItems();
      
      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        state = AsyncValue.data([...currentItems, ...newItems]);
      }
    } catch (error, stackTrace) {
      // Don't update state to error when loading more, just print the error
      print('Error loading more items: $error');
    }
  }

  Future<List<ItemModel>> _fetchItems() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('items')
          .where('status', isEqualTo: 'available')
          .orderBy('createdAt', descending: true);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(_pageSize).get();
      
      if (snapshot.docs.isEmpty) {
        return [];
      }

      _lastDocument = snapshot.docs.last;
      
      // Convert to ItemModel list but don't shuffle (to maintain consistency)
      final items = snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
      return items;
    } catch (e) {
      print('Error fetching items: $e');
      // If the error is about missing index, return a special error
      if (e.toString().contains('index') && e.toString().contains('firebase')) {
        throw 'Firestore index is being created. Please try again in a few minutes.';
      }
      return [];
    }
  }

  void refresh() {
    _lastDocument = null;
    _hasMore = true;
    _isInitialized = false;
    loadInitialItems();
  }
} 