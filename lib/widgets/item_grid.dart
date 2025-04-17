import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/item_model.dart';
import '../utils/currency_formatter.dart';
import '../providers/user_provider.dart';

class ItemGrid extends ConsumerWidget {
  final List<ItemModel> items;
  final bool isLoading;
  final ScrollController scrollController;
  final Function() onLoadMore;
  final Function() onRefresh;

  const ItemGrid({
    Key? key,
    required this.items,
    required this.isLoading,
    required this.scrollController,
    required this.onLoadMore,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
        return Future<void>.value();
      },
      child: items.isEmpty && !isLoading
          ? const Center(child: Text('No items found'))
          : GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55, // Make cards taller to avoid overflow
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final item = items[index];
                return ItemCard(item: item);
              },
            ),
    );
  }
}

class ItemCard extends ConsumerWidget {
  final ItemModel item;

  const ItemCard({required this.item, Key? key}) : super(key: key);

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

  const SellerInfo({required this.sellerId, Key? key}) : super(key: key);

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