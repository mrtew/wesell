import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_bar_widget.dart';
import '../../widgets/item_grid.dart';
import '../../providers/item_provider.dart';

class ItemPostedScreen extends ConsumerStatefulWidget {
  const ItemPostedScreen({super.key});

  @override
  ConsumerState<ItemPostedScreen> createState() => _ItemPostedScreenState();
}

class _ItemPostedScreenState extends ConsumerState<ItemPostedScreen> {
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
        ref.read(userPostedItemsProvider.notifier).loadMoreItems().then((_) {
          if (mounted) {
            setState(() => _isLoadingMore = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsyncValue = ref.watch(userPostedItemsProvider);
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Items Posted',
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
                  ref.read(userPostedItemsProvider.notifier).refresh();
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
              ref.read(userPostedItemsProvider.notifier).loadMoreItems();
            },
            onRefresh: () {
              ref.read(userPostedItemsProvider.notifier).refresh();
            },
          );
        },
      ),
    );
  }
} 