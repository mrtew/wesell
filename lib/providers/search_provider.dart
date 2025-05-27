import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/search_controller.dart';
import '../models/item_model.dart';

// Search controller provider
final searchControllerProvider = Provider<SearchController>((ref) {
  return SearchController();
});

// Current search text provider
final searchTextProvider = StateProvider<String>((ref) => '');

// Search results provider for text search
final textSearchResultsProvider = StateNotifierProvider<TextSearchNotifier, AsyncValue<List<ItemModel>>>((ref) {
  return TextSearchNotifier(ref);
});

class TextSearchNotifier extends StateNotifier<AsyncValue<List<ItemModel>>> {
  final Ref _ref;
  Timer? _debounce;
  String _lastSearched = '';

  TextSearchNotifier(this._ref) : super(const AsyncValue.data([]));

  Future<void> searchItems(String searchText, {bool immediate = false}) async {
    // If text is unchanged, don't do anything
    if (_lastSearched == searchText && !immediate) return;
    
    // Cancel existing timer
    _debounce?.cancel();
    
    if (!immediate) {
      // Set a new timer
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch(searchText);
      });
    } else {
      // Perform search immediately without debounce
      _performSearch(searchText);
    }
  }

  Future<void> _performSearch(String searchText) async {
    if (searchText.isEmpty) {
      state = const AsyncValue.data([]);
      _lastSearched = '';
      return;
    }

    try {
      state = const AsyncValue.loading();
      _lastSearched = searchText;
      
      final searchController = _ref.read(searchControllerProvider);
      final results = await searchController.searchItemsByText(searchText);
      
      state = AsyncValue.data(results);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clearSearch() {
    _lastSearched = '';
    state = const AsyncValue.data([]);
  }
}

// Image search results provider
final imageSearchResultsProvider = StateNotifierProvider<ImageSearchNotifier, AsyncValue<List<ItemModel>>>((ref) {
  return ImageSearchNotifier(ref);
});

class ImageSearchNotifier extends StateNotifier<AsyncValue<List<ItemModel>>> {
  final Ref _ref;

  ImageSearchNotifier(this._ref) : super(const AsyncValue.data([]));

  Future<void> searchItemsByImage(File imageFile) async {
    try {
      state = const AsyncValue.loading();
      
      final searchController = _ref.read(searchControllerProvider);
      final results = await searchController.searchItemsByImage(imageFile);
      
      state = AsyncValue.data(results);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void clearSearch() {
    state = const AsyncValue.data([]);
  }
} 