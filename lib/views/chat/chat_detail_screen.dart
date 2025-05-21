import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_bar_widget.dart';
import '../../models/chat_model.dart';

// State provider to hold the chat ID once a new chat is created
final newChatIdProvider = StateProvider<String?>((ref) => null);

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String? chatId;
  final String? sellerId;

  const ChatDetailScreen({
    this.chatId,
    this.sellerId,
    super.key,
  }) : assert(chatId != null || sellerId != null, "Either chatId or sellerId must be provided");

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  String? _dynamicChatId;

  @override
  void initState() {
    super.initState();
    
    // Reset the dynamic chat ID and the global provider when creating a new screen
    _dynamicChatId = null;
    
    // Clear the global newChatIdProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newChatIdProvider.notifier).state = null;
    });
    
    debugPrint('ChatDetailScreen initialized with sellerId: ${widget.sellerId}, chatId: ${widget.chatId}');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the sellerId has changed, reset the dynamic chat ID to force a new chat context
    if (widget.sellerId != null && oldWidget.sellerId != null && 
        widget.sellerId != oldWidget.sellerId) {
      debugPrint('Seller changed from ${oldWidget.sellerId} to ${widget.sellerId}');
      
      // Reset dynamic chat ID to null
      setState(() {
        _dynamicChatId = null;
      });
      
      // Also clear the global newChatIdProvider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(newChatIdProvider.notifier).state = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    
    // Listen for new chat IDs (when a new chat is created)
    final newChatId = ref.watch(newChatIdProvider);
    
    // If we have a dynamic chat ID, use it over the widget's chatId
    final effectiveChatId = _dynamicChatId ?? newChatId ?? widget.chatId;
    
    return Stack(
      children: [
        // Main chat screen UI
        _buildMainChatUI(currentUserAsync, effectiveChatId),
        
        // Full-screen loading overlay
        if (_isUploading)
          _buildFullScreenLoading(),
      ],
    );
  }

  Widget _buildFullScreenLoading() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Sending image...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainChatUI(AsyncValue<dynamic> currentUserAsync, String? effectiveChatId) {
    return currentUserAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: const AppBarWidget(
          title: 'Error',
          showBackButton: true,
        ),
        body: const Center(child: Text('Error loading user data')),
      ),
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            appBar: AppBarWidget(
              title: 'Chat',
              showBackButton: true,
            ),
            body: Center(child: Text('You need to be logged in')),
          );
        }

        // If we have a chat ID (either from widget or dynamically created)
        if (effectiveChatId != null) {
          // Existing chat
          final chatAsync = ref.watch(chatByIdProvider(effectiveChatId));
          
          return chatAsync.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) {
              debugPrint('Error loading chat: $error');
              debugPrint('Stack trace: $stack');
              return Scaffold(
                appBar: const AppBarWidget(
                  title: 'Error',
                  showBackButton: true,
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Error loading chat'),
                      Text(error.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ElevatedButton(
                        onPressed: () {
                          ref.refresh(chatByIdProvider(effectiveChatId));
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            },
            data: (chat) {
              if (chat == null) {
                return const Scaffold(
                  appBar: AppBarWidget(
                    title: 'Chat not found',
                    showBackButton: true,
                  ),
                  body: Center(child: Text('This chat doesn\'t exist')),
                );
              }
              
              // Get the other user's ID
              final otherUserId = chat.userIds['sender'] == currentUser.uid 
                  ? chat.userIds['receiver'] 
                  : chat.userIds['sender'];
              
              return _buildChatScreen(context, currentUser.uid, otherUserId, chat.messages);
            },
          );
        } else {
          // New chat with a seller
          final sellerAsync = ref.watch(sellerByIdProvider(widget.sellerId!));
          
          return sellerAsync.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, __) {
              debugPrint('Error loading seller: $error');
              return Scaffold(
                appBar: const AppBarWidget(
                  title: 'Error',
                  showBackButton: true,
                ),
                body: const Center(child: Text('Error loading seller data')),
              );
            },
            data: (seller) {
              if (seller == null) {
                return const Scaffold(
                  appBar: AppBarWidget(
                    title: 'Seller not found',
                    showBackButton: true,
                  ),
                  body: Center(child: Text('This seller doesn\'t exist')),
                );
              }
              
              // Check if a chat already exists between these users
              ref.listen(
                chatBetweenUsersProvider({
                  'currentUserId': currentUser.uid,
                  'otherUserId': seller.uid,
                }), 
                (previous, next) {
                  next.whenData((chat) {
                    if (chat != null && _dynamicChatId == null) {
                      // If we found an existing chat, update the dynamic chat ID
                      setState(() {
                        _dynamicChatId = chat.id;
                      });
                    }
                  });
                }
              );
              
              // If we've discovered an existing chat, use the chat ID screen
              if (_dynamicChatId != null) {
                final chatAsync = ref.watch(chatByIdProvider(_dynamicChatId!));
                return chatAsync.when(
                  loading: () => _buildLoadingChatScreen(seller),
                  error: (_, __) => _buildEmptyChatScreen(context, currentUser.uid, seller.uid, seller),
                  data: (chat) {
                    if (chat == null) {
                      return _buildEmptyChatScreen(context, currentUser.uid, seller.uid, seller);
                    }
                    return _buildChatScreen(
                      context,
                      currentUser.uid,
                      seller.uid,
                      chat.messages,
                      sellerData: seller,
                    );
                  }
                );
              }
              
              // Otherwise, build an empty chat screen with just the seller info
              return _buildEmptyChatScreen(context, currentUser.uid, seller.uid, seller);
            },
          );
        }
      },
    );
  }

  Widget _buildLoadingChatScreen(dynamic seller) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildSellerAppBar(seller),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyChatScreen(
    BuildContext context,
    String currentUserId,
    String otherUserId,
    dynamic seller,
  ) {
    return _buildChatScreen(
      context,
      currentUserId,
      otherUserId,
      [],
      sellerData: seller,
    );
  }

  Widget _buildChatScreen(
    BuildContext context,
    String currentUserId,
    String otherUserId,
    List<Map<String, dynamic>> messages, {
    dynamic sellerData,
  }) {
    // If sellerData is not provided, fetch it
    Widget appBar;
    if (sellerData != null) {
      appBar = _buildSellerAppBar(sellerData);
    } else {
      final sellerAsync = ref.watch(sellerByIdProvider(otherUserId));
      appBar = sellerAsync.when(
        loading: () => const AppBarWidget(
          title: 'Loading...',
          showBackButton: true,
        ),
        error: (error, stackTrace) {
          debugPrint('Error loading seller data: $error');
          return const AppBarWidget(
            title: 'Chat',
            showBackButton: true,
          );
        },
        data: (seller) {
          if (seller == null) {
            return const AppBarWidget(
              title: 'Chat',
              showBackButton: true,
            );
          }
          return _buildSellerAppBar(seller);
        },
      );
    }

    // Create a reversed message list for display
    final List<Map<String, dynamic>> reversedMessages = messages.isNotEmpty
        ? List.from(messages.reversed)
        : [];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: appBar,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    reverse: true, // Start from bottom
                    itemCount: reversedMessages.length,
                    itemBuilder: (context, index) {
                      final message = reversedMessages[index];
                      final isCurrentUser = message['senderId'] == currentUserId;
                      final messageTimestamp = message['timestamp'] as Timestamp;
                      
                      return _buildMessageItem(
                        context,
                        isCurrentUser,
                        message['type'],
                        message['content'],
                        messageTimestamp,
                      );
                    },
                  ),
          ),
          // Message input
          _buildMessageInput(context, currentUserId, otherUserId),
        ],
      ),
    );
  }

  Widget _buildSellerAppBar(dynamic seller) {
    return AppBar(
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            backgroundImage: seller.avatar != null && seller.avatar.isNotEmpty
                ? CachedNetworkImageProvider(seller.avatar)
                : null,
            child: seller.avatar == null || seller.avatar.isEmpty
                ? const Icon(Icons.person, size: 20, color: Colors.white)
                : null,
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
                if (seller.isIdentityVerified == true) const SizedBox(width: 10),
                if (seller.isIdentityVerified == true)
                  Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: Colors.blue[300],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    bool isCurrentUser,
    String type,
    String content,
    Timestamp timestamp,
  ) {
    final time = DateFormat('HH:mm').format(timestamp.toDate());
    
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.green[200] : Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message content
            if (type == 'text')
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    color: isCurrentUser ? Colors.black : Colors.black,
                    // fontWeight: FontWeight.bold, 
                  ),
                ),
              )
            else if (type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: GestureDetector(
                  onTap: () => _viewFullImage(context, content),
                  child: CachedNetworkImage(
                    imageUrl: content,
                    placeholder: (context, url) => const SizedBox(
                      height: 144,
                      width: 144,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox(
                      height: 144,
                      width: 144,
                      child: Center(child: Icon(Icons.error)),
                    ),
                  ),
                ),
              ),
            
            // Time
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4, left: 8),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrentUser ? Colors.black : Colors.black,
                  // fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(
    BuildContext context,
    String currentUserId,
    String otherUserId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      child: Row(
        children: [
          // Gallery button
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _isUploading
                ? null
                : () => _pickImage(currentUserId, otherUserId),
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendTextMessage(currentUserId, otherUserId),
            ),
          ),
          // Send button
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: Colors.green,
            onPressed: () => _sendTextMessage(currentUserId, otherUserId),
          ),
        ],
      ),
    );
  }

  void _sendTextMessage(String currentUserId, String otherUserId) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      // Clear the text field immediately for better UX
      _messageController.clear();
      
      // Get the existing chat to check if it exists
      ChatModel? existingChat = await ref.read(chatControllerProvider).getChatByUsers(currentUserId, otherUserId);
      
      // Send the message
      await ref.read(chatControllerProvider).sendTextMessage(
        currentUserId,
        otherUserId,
        message,
      );
      
      // If no existing chat was found before sending, we need to fetch the new chat ID
      if (existingChat == null) {
        // Get the newly created chat
        ChatModel? newChat = await ref.read(chatControllerProvider).getChatByUsers(currentUserId, otherUserId);
        if (newChat != null) {
          // Update the dynamic chat ID to switch to a stream of this chat
          setState(() {
            _dynamicChatId = newChat.id;
          });
          // Also update the provider for potential listeners
          ref.read(newChatIdProvider.notifier).state = newChat.id;
        }
      }
    } catch (error) {
      debugPrint('Error sending message: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $error')),
        );
      }
    }
  }

  Future<void> _pickImage(String currentUserId, String otherUserId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // Show image preview dialog
        if (!mounted) return;
        
        final bool shouldSend = await _showImageConfirmationDialog(image.path);
        
        if (shouldSend && mounted) {
          await _sendImageMessage(currentUserId, otherUserId, image);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }
  
  Future<bool> _showImageConfirmationDialog(String imagePath) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send this image?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(
                File(imagePath),
                height: 300,
                fit: BoxFit.contain,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,       // Set text color
                  // fontWeight: FontWeight.bold, // Make it bold
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[200],
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Send',
                style: TextStyle(
                  color: Colors.black,       // Set text color
                  // fontWeight: FontWeight.bold, // Make it bold
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed
  }

  Future<void> _sendImageMessage(String currentUserId, String otherUserId, XFile image) async {
    setState(() {
      _isUploading = true;
    });
    
    try {
      // Get the existing chat to check if it exists
      ChatModel? existingChat = await ref.read(chatControllerProvider).getChatByUsers(currentUserId, otherUserId);
      
      // Send the image
      await ref
          .read(chatControllerProvider)
          .sendImageMessage(currentUserId, otherUserId, image);
      
      // If no existing chat was found before sending, we need to fetch the new chat ID
      if (existingChat == null) {
        // Get the newly created chat
        ChatModel? newChat = await ref.read(chatControllerProvider).getChatByUsers(currentUserId, otherUserId);
        if (newChat != null) {
          // Update the dynamic chat ID to switch to a stream of this chat
          setState(() {
            _dynamicChatId = newChat.id;
          });
          // Also update the provider for potential listeners
          ref.read(newChatIdProvider.notifier).state = newChat.id;
        }
      }
    } catch (e) {
      debugPrint('Error sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _viewFullImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 