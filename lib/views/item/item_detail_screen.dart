import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:wesell/views/chat/chat_screen.dart';
import '../../providers/item_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_bar_widget.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;

  const ItemDetailScreen({required this.itemId, super.key});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  final _chatIcon = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return itemAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: const AppBarWidget(
          title: 'Error',
          showBackButton: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading item: ${error.toString().split('\n').first}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(itemByIdProvider(widget.itemId));
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
      data: (item) {
        if (item == null) {
          return const Scaffold(
            appBar: AppBarWidget(
              title: 'Not Found',
              showBackButton: true,
            ),
            body: Center(child: Text('Item not found')),
          );
        }
        
        final isOwner = currentUserAsync.maybeWhen(
          data: (user) => user?.uid == item.sellerId,
          orElse: () => false,
        );

        final bool showItemActions = 
            currentUserAsync.hasValue && 
            item.status == 'available';

        // Only show chat icon if the user is authenticated, not the owner, and authentication check is complete
        final bool showChatIcon = currentUserAsync.maybeWhen(
          data: (user) => user != null && !isOwner,
          orElse: () => false,
        );

        return Scaffold(
          appBar: AppBar(
            elevation: 2,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => GoRouter.of(context).pop(),
            ),
            title: ref.watch(sellerByIdProvider(item.sellerId)).when(
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Seller'),
              data: (seller) {
                if (seller == null) {
                  return const Text('Unknown Seller');
                }
                
                final hasAvatar = seller.avatar != null && seller.avatar.isNotEmpty;
                
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: hasAvatar 
                          ? CachedNetworkImageProvider(seller.avatar) 
                          : null,
                      child: !hasAvatar ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            seller.username.isNotEmpty ? seller.username : 'User',
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
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
            ),
            actions: showChatIcon ? [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () {
                  // Navigate to the chat screen with this seller
                  GoRouter.of(context).push('/chat/new/${item.sellerId}');
                },
              ),
            ] : [],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Carousel - now inside SingleChildScrollView to enable full page scrolling
                SizedBox(
                  height: 300,
                  child: Stack(
                    children: [
                      // Image Carousel
                      PageView.builder(
                        controller: _pageController,
                        itemCount: item.images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              _openFullScreenImage(context, item.images, index);
                            },
                            child: CachedNetworkImage(
                              imageUrl: item.images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                                // child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error, size: 50),
                              ),
                            ),
                          );
                        },
                      ),
                      // Pagination Dots
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            item.images.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? Colors.amber
                                    : Colors.grey[300],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Item Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'RM${formatMoney(item.price)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                'RM${formatMoney(item.originalPrice)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            item.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              color: item.status == 'available' ? Colors.green : Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Category: ',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Description
                      const Text(
                        'Description: ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: showItemActions
              ? _buildBottomButtons(context, item, isOwner)
              : null,
        );
      },
    );
  }

  Widget _buildSellerInfo(String sellerId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ref.watch(sellerByIdProvider(sellerId)).when(
            loading: () => const CircularProgressIndicator(strokeWidth: 2),
            error: (_, __) => const Icon(Icons.error),
            data: (seller) {
              if (seller == null) {
                return const Text('Unknown Seller');
              }
              
              final hasAvatar = seller.avatar != null && seller.avatar.isNotEmpty;
              
              return Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate to seller profile or show more details
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: hasAvatar 
                          ? CachedNetworkImageProvider(seller.avatar) 
                          : null,
                      child: !hasAvatar ? const Icon(Icons.person, size: 24, color: Colors.white) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller.username.isNotEmpty ? seller.username : 'User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Seller',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              // Chat feature
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context, dynamic item, bool isOwner) {
    // First check if user authentication is still loading
    final currentUserAsync = ref.watch(currentUserProvider);
    if (currentUserAsync.isLoading) {
      return const SizedBox.shrink(); // Don't show buttons while checking authentication
    }
    
    // Only show buttons if item is available
    if (item.status != 'available') {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: isOwner
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleEditItem(context, item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Edit Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleDeleteItem(context, item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Delete Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to payment method screen
                  GoRouter.of(context).push('/payment/${item.itemId}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Buy Item',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
    );
  }

  void _handleEditItem(BuildContext context, dynamic item) async {
    // Navigate to edit screen with item data
    final result = await GoRouter.of(context).push<bool>('/item/${item.itemId}/edit');
    
    // If edit was successful, refresh the item data
    if (result == true) {
      // Refresh both item and user data
      ref.refresh(itemByIdProvider(item.itemId));
      ref.refresh(currentUserProvider);
      ref.read(homeItemsProvider.notifier).refresh();
      ref.read(userPostedItemsProvider.notifier).refresh();
    }
  }
  
  void _handleDeleteItem(BuildContext context, dynamic item) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // First dismiss the dialog
              Navigator.of(context).pop();
              
              // Show a non-dismissible loading dialog with a timeout counter
              int timeoutSeconds = 20;
              bool isDeleting = true;
              BuildContext? dialogContext;
              
              // Create a timer that updates the message every second
              Timer? countdownTimer;
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  dialogContext = context;
                  
                  return StatefulBuilder(
                    builder: (context, setState) {
                      // Start the countdown timer when dialog is first shown
                      countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
                        if (timeoutSeconds > 0 && isDeleting) {
                          setState(() {
                            timeoutSeconds--;
                          });
                        } else if (timeoutSeconds <= 0 && isDeleting) {
                          // Auto-cancel after timeout
                          timer.cancel();
                          isDeleting = false;
                          Navigator.of(context).pop();
                          
                          // Show error message for timeout
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Operation Timed Out'),
                              content: const Text('The delete operation is taking longer than expected. '
                                  'It might still be processing in the background.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      });
                      
                      return WillPopScope(
                        onWillPop: () async => false,
                        child: AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text("Deleting item..."),
                              const SizedBox(height: 8),
                              Text(
                                "Please wait...",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
              
              try {
                // Call the delete method
                await ref.read(itemControllerProvider).deleteItem(item.itemId);
                
                // Cancel the timer
                countdownTimer?.cancel();
                isDeleting = false;
                
                // Close dialog if it's still open
                if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                  Navigator.of(dialogContext!).pop();
                }
                
                // Refresh data
                ref.refresh(currentUserProvider);
                ref.read(homeItemsProvider.notifier).refresh();
                ref.read(userPostedItemsProvider.notifier).refresh();
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item deleted successfully')),
                );
                
                // Return to previous screen with success result
                if (mounted && context.mounted) {
                  GoRouter.of(context).pop(true);
                }
              } catch (error) {
                // Cancel the timer
                countdownTimer?.cancel();
                isDeleting = false;
                
                // Log detailed error
                debugPrint('Error deleting item: $error');
                
                // Close dialog if it's still open
                if (dialogContext != null && Navigator.canPop(dialogContext!)) {
                  Navigator.of(dialogContext!).pop();
                }
                
                // Show error dialog
                if (mounted && context.mounted) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Error"),
                        content: SingleChildScrollView(
                          child: Text(
                            "Failed to delete item: ${error.toString()}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: const Text("OK"),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          TextButton(
                            child: const Text("Try Again"),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _handleDeleteItem(context, item);
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: PageView.builder(
                  controller: PageController(initialPage: initialIndex),
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 