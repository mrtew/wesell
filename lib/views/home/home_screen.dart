import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_bar_widget.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../models/item_model.dart';
import '../../controllers/user_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    // Refresh user data when screen loads
    Future.microtask(() => ref.refresh(currentUserProvider));
    
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
        ref.read(homeItemsProvider.notifier).loadMoreItems().then((_) {
          if (mounted) {
            setState(() => _isLoadingMore = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidget(
        title: 'WeSell',
        showBackButton: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homeItemsProvider.notifier).refresh();
          return Future<void>.value();
        },
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () {
                      // TODO: Implement image search
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onTap: () {
                  // TODO: Implement search
                },
              ),
            ),
            // Items Grid
            Expanded(
              child: ref.watch(homeItemsProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${error.toString().split('\n').first}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(homeItemsProvider.notifier).refresh();
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('No items found'));
                  }
                  return GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.55, // Make cards taller to avoid overflow
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final item = items[index];
                      return _ItemCard(item: item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final ItemModel item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/item/${item.itemId}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: item.images.isNotEmpty 
                      ? item.images.first 
                      : 'https://via.placeholder.com/150',
                  fit: BoxFit.cover,
                  // placeholder: (context, url) => const Center(
                  //   child: CircularProgressIndicator(),
                  // ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            // Item Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      'RM${formatMoney(item.price)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'RM${formatMoney(item.originalPrice)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Spacer(), // Push seller info to bottom
                    // Seller Info
                    SellerInfo(sellerId: item.sellerId),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Separate widget for seller info to improve performance
class SellerInfo extends ConsumerWidget {
  final String sellerId;

  const SellerInfo({required this.sellerId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the cached seller provider
    final sellerAsync = ref.watch(sellerByIdProvider(sellerId));
    
    // Create a placeholder widget to show while loading
    Widget placeholder = Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Colors.grey[300],
          child: const Icon(Icons.person, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Loading...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
    
    return sellerAsync.when(
      loading: () => placeholder,
      error: (_, __) => placeholder,
      data: (seller) {
        if (seller == null) {
          return placeholder;
        }
        
        final hasAvatar = seller.avatar != null && seller.avatar.isNotEmpty;
        
        return Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey[300],
              backgroundImage: hasAvatar 
                  ? CachedNetworkImageProvider(seller.avatar) 
                  : null,
              child: !hasAvatar ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                seller.username.isNotEmpty ? seller.username : 'User',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
