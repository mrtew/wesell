import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/item_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';
import '../providers/user_provider.dart';

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
    imageFiles: itemData['imageFiles'] as List<File>, // Compressed images for upload
    originalImageFiles: itemData['originalImageFiles'] as List<File>?, // Original images for ML Kit
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

// Provider for fetching multiple items by IDs
final itemsByIdsProvider = StateNotifierProvider.family<ItemsByIdsNotifier, AsyncValue<List<ItemModel>>, List<String>>(
  (ref, itemIds) => ItemsByIdsNotifier(ref, itemIds),
);

class ItemsByIdsNotifier extends StateNotifier<AsyncValue<List<ItemModel>>> {
  final Ref _ref;
  final List<String> _itemIds;
  final int _pageSize = 10;
  List<ItemModel> _allItems = [];
  int _displayedCount = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  ItemsByIdsNotifier(this._ref, this._itemIds) : super(const AsyncValue.loading()) {
    if (_itemIds.isEmpty) {
      state = const AsyncValue.data([]);
    } else {
      _loadAllItems();
    }
  }

  Future<void> _loadAllItems() async {
    if (_isLoading || _itemIds.isEmpty) return;
    
    try {
      _isLoading = true;
      state = const AsyncValue.loading();
      
      // Fetch all items at once
      final itemController = _ref.read(itemControllerProvider);
      final itemFutures = _itemIds.map((id) => itemController.getItemById(id));
      final fetchedItems = await Future.wait(itemFutures);
      
      // Filter out null items and order them based on the position in
      // the user's list of IDs (descending ‒ last ID appears first).
      _allItems = fetchedItems
          .whereType<ItemModel>()
          .toList();

      // Build a map of itemId -> index for quick lookup
      final Map<String, int> _idOrder = {
        for (int i = 0; i < _itemIds.length; i++) _itemIds[i]: i,
      };
      _allItems.sort((a, b) {
        final aIndex = _idOrder[a.itemId] ?? 0;
        final bIndex = _idOrder[b.itemId] ?? 0;
        // Higher index (later in the array) should come first
        return bIndex.compareTo(aIndex);
      });
      
      // Set the initial displayed items
      _displayedCount = _pageSize > _allItems.length ? _allItems.length : _pageSize;
      _hasMore = _displayedCount < _allItems.length;
      
      state = AsyncValue.data(_allItems.sublist(0, _displayedCount));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadInitialItems() async {
    if (_allItems.isEmpty) {
      await _loadAllItems();
    } else {
      // Reset pagination
      _displayedCount = _pageSize > _allItems.length ? _allItems.length : _pageSize;
      _hasMore = _displayedCount < _allItems.length;
      state = AsyncValue.data(_allItems.sublist(0, _displayedCount));
    }
  }

  Future<void> loadMoreItems() async {
    if (_isLoading || !_hasMore) return;
    
    try {
      _isLoading = true;
      
      final newEndIndex = _displayedCount + _pageSize > _allItems.length 
          ? _allItems.length 
          : _displayedCount + _pageSize;
      
      if (newEndIndex > _displayedCount) {
        _displayedCount = newEndIndex;
        _hasMore = _displayedCount < _allItems.length;
        state = AsyncValue.data(_allItems.sublist(0, _displayedCount));
      } else {
        _hasMore = false;
      }
    } catch (error, stackTrace) {
      print('Error loading more items: $error');
    } finally {
      _isLoading = false;
    }
  }

  void refresh() {
    _allItems = [];
    _displayedCount = 0;
    _hasMore = true;
    _loadAllItems();
  }
}

// Providers for user-specific item lists
final userPostedItemsProvider = StateNotifierProvider<UserItemsNotifier, AsyncValue<List<ItemModel>>>(
  (ref) => UserItemsNotifier(ref, 'posted'),
);

final userPurchasedItemsProvider = StateNotifierProvider<UserItemsNotifier, AsyncValue<List<ItemModel>>>(
  (ref) => UserItemsNotifier(ref, 'purchased'),
);

final userSoldItemsProvider = StateNotifierProvider<UserItemsNotifier, AsyncValue<List<ItemModel>>>(
  (ref) => UserItemsNotifier(ref, 'sold'),
);

class UserItemsNotifier extends StateNotifier<AsyncValue<List<ItemModel>>> {
  final Ref _ref;
  final String _type; // 'posted', 'purchased', or 'sold'
  ItemsByIdsNotifier? _itemsNotifier;

  UserItemsNotifier(this._ref, this._type) : super(const AsyncValue.loading()) {
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      state = const AsyncValue.loading();
      
      // Get current user
      final user = await _ref.read(currentUserProvider.future);
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }
      
      // Get the appropriate list of item IDs based on the type
      List<String> itemIds = [];
      switch (_type) {
        case 'posted':
          itemIds = user.itemsPosted;
          break;
        case 'purchased':
          itemIds = user.itemsPurchased;
          break;
        case 'sold':
          itemIds = user.itemsSold;
          break;
      }
      
      // Create a new notifier for these IDs
      _itemsNotifier = ItemsByIdsNotifier(_ref, itemIds);
      
      // Update state to match the items notifier
      _itemsNotifier!.addListener((itemsState) {
        state = itemsState;
      });
      
      // Load initial items
      await _itemsNotifier!.loadInitialItems();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<void> loadMoreItems() async {
    _itemsNotifier?.loadMoreItems();
  }
  
  void refresh() {
    _loadItems();
  }
} 