import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_bar_widget.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Chat',
        showBackButton: false,
      ),
      body: currentUserAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading conversations'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(currentUserProvider);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (currentUser) {
          if (currentUser == null) {
            return const Center(
              child: Text('You need to be logged in to view your conversations'),
            );
          }
          
          return _buildChatList(context, ref, currentUser.uid);
        },
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
  
  Widget _buildChatList(BuildContext context, WidgetRef ref, String userId) {
    final chatsAsync = ref.watch(userChatsProvider(userId));
    
    return chatsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) {
        // Log error for debugging
        debugPrint('Error in userChatsProvider: $error');
        debugPrint('Stack trace: $stackTrace');
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading conversations'),
              Text('Details: ${error.toString()}', 
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Refresh providers
                  ref.invalidate(userChatsProvider(userId));
                  ref.refresh(userChatsProvider(userId));
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      },
      data: (chats) {
        // Log for debugging
        debugPrint('Loaded ${chats.length} chats for user $userId');
        
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No conversations yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start chatting with sellers by viewing their items',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                // ElevatedButton(
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.amber,
                //     foregroundColor: Colors.white,
                //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                //   ),
                //   onPressed: () {
                //     // Navigate to home screen
                //     GoRouter.of(context).go('/home');
                //   },
                //   child: const Text('Browse Items'),
                // ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return _buildChatItem(context, ref, userId, chat);
          },
        );
      },
    );
  }
  
  Widget _buildChatItem(BuildContext context, WidgetRef ref, String currentUserId, ChatModel chat) {
    // Determine the other user ID (seller or buyer)
    final otherUserId = chat.userIds['sender'] == currentUserId
        ? chat.userIds['receiver']
        : chat.userIds['sender'];
    
    // Get the other user's data
    final otherUserAsync = ref.watch(sellerByIdProvider(otherUserId));
    
    // Get the last message
    final lastMessage = chat.messages.isNotEmpty ? chat.messages.last : null;
    
    return otherUserAsync.when(
      loading: () => const ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        title: Text('Loading...'),
      ),
      error: (_, __) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red[100],
          child: const Icon(Icons.error, color: Colors.red),
        ),
        title: const Text('Error loading user data'),
        onTap: () => ref.refresh(sellerByIdProvider(otherUserId)),
      ),
      data: (otherUser) {
        if (otherUser == null) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text('Unknown User'),
          );
        }
        
        // Format the date
        String formattedDate = '';
        if (chat.updatedAt != null) {
          final now = DateTime.now();
          final chatDate = chat.updatedAt.toDate();
          final difference = now.difference(chatDate);
          
          if (difference.inDays == 0) {
            // Today - show time
            formattedDate = DateFormat('HH:mm').format(chatDate);
          } else if (difference.inDays == 1) {
            // Yesterday
            formattedDate = 'Yesterday';
          } else if (difference.inDays < 7) {
            // This week - show day name
            formattedDate = DateFormat('EEEE').format(chatDate);
          } else {
            // Older - show date
            formattedDate = DateFormat('dd/MM/yyyy').format(chatDate);
          }
        }
        
        final hasAvatar = otherUser.avatar != null && otherUser.avatar.isNotEmpty;
        
        return InkWell(
          onTap: () {
            // Navigate to chat detail
            GoRouter.of(context).push('/chat/${chat.id}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: hasAvatar
                      ? CachedNetworkImageProvider(otherUser.avatar)
                      : null,
                  child: !hasAvatar
                      ? const Icon(Icons.person, size: 28, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                
                // User info and last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username and verification
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              otherUser.username.isNotEmpty ? otherUser.username : 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (otherUser.isIdentityVerified == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Colors.blue[300],
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Last message
                      if (lastMessage != null)
                        Text(
                          lastMessage['type'] == 'text'
                              ? lastMessage['content']
                              : '[Image]',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                
                // Chat date
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 