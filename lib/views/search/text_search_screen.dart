import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/search_provider.dart';
import '../../widgets/search_bar_widget.dart';
import '../../models/item_model.dart';
import '../../utils/currency_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/user_provider.dart';

class TextSearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const TextSearchScreen({
    Key? key,
    required this.initialQuery,
  }) : super(key: key);

  @override
  ConsumerState<TextSearchScreen> createState() => _TextSearchScreenState();
}

class _TextSearchScreenState extends ConsumerState<TextSearchScreen> {
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    
    // Perform the initial search
    Future.microtask(() {
      final searchNotifier = ref.read(textSearchResultsProvider.notifier);
      searchNotifier.searchItems(_searchController.text, immediate: true);
      ref.read(searchTextProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(textSearchResultsProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: SearchBarWidget(
          controller: _searchController,
          showCameraIcon: false,
          autofocus: false,
          onSubmitted: (value) {
            ref.read(textSearchResultsProvider.notifier).searchItems(value, immediate: true);
            ref.read(searchTextProvider.notifier).state = value;
          },
          onSearch: () {
            ref.read(textSearchResultsProvider.notifier).searchItems(
              _searchController.text, 
              immediate: true
            );
            ref.read(searchTextProvider.notifier).state = _searchController.text;
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        titleSpacing: 0,
      ),
      body: searchResults.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${error.toString().split('\n').first}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(textSearchResultsProvider.notifier).searchItems(
                    _searchController.text, 
                    immediate: true
                  );
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
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if(_searchController.text == '')...{
                            const Icon(Icons.search_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'Use the search bar to find items',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            // const Text(
                            //   'Try a different search term',
                            //   style: TextStyle(fontSize: 14, color: Colors.grey),
                            // ),
                          }else...{
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No items found for "${_searchController.text}"',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try a different search term',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          },
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