import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/item_grid.dart';
import '../../providers/item_provider.dart';

class ItemSoldScreen extends ConsumerStatefulWidget {
  const ItemSoldScreen({super.key});

  @override
  ConsumerState<ItemSoldScreen> createState() => _ItemSoldScreenState();
}

class _ItemSoldScreenState extends ConsumerState<ItemSoldScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    
    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore) {
        setState(() => _isLoadingMore = true);
        ref.read(userSoldItemsProvider.notifier).loadMoreItems().then((_) {
          if (mounted) {
            setState(() => _isLoadingMore = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsyncValue = ref.watch(userSoldItemsProvider);
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Items Sold',
        showBackButton: true,
      ),
      body: itemsAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${error.toString().split('\n').first}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(userSoldItemsProvider.notifier).refresh();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (items) {
          return ItemGrid(
            items: items,
            isLoading: _isLoadingMore,
            scrollController: _scrollController,
            onLoadMore: () {
              ref.read(userSoldItemsProvider.notifier).loadMoreItems();
            },
            onRefresh: () {
              ref.read(userSoldItemsProvider.notifier).refresh();
            },
          );
        },
      ),
    );
  }
} 