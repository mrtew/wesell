import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/search_provider.dart';
import '../../models/item_model.dart';
import '../../utils/currency_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/user_provider.dart';

class ImageSearchScreen extends ConsumerStatefulWidget {
  final File imageFile;
  
  const ImageSearchScreen({
    Key? key,
    required this.imageFile,
  }) : super(key: key);

  @override
  ConsumerState<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends ConsumerState<ImageSearchScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Perform the image search when screen initializes
    Future.microtask(() {
      ref.read(imageSearchResultsProvider.notifier).searchItemsByImage(widget.imageFile);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(imageSearchResultsProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
        'Image Search Result',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Display the search image
          Container(
            width: double.infinity,
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16/9,
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.contain,
              ),
            ),
          ),
          
          // Search results
          Expanded(
            child: searchResults.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${error.toString().split('\n').first}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(imageSearchResultsProvider.notifier)
                          .searchItemsByImage(widget.imageFile);
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_search, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No similar items found',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try a different image',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                
                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemCard(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
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
              child: Row(
                children: [
                  Text(
                    seller.username.isNotEmpty ? seller.username : 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if(seller.isIdentityVerified == true)
                  SizedBox(width: 10),
                  if(seller.isIdentityVerified == true)
                  Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: Colors.blue[300],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
} 