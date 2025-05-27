import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_model.dart';
import '../providers/user_provider.dart';
import 'package:flutter/foundation.dart';

// Provider for chat controller
final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    ref.watch(userControllerProvider),
    ref,
  );
});

// Provider for user's chats
final userChatsProvider = StreamProvider.family<List<ChatModel>, String>((ref, userId) {
  try {
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    return ref.watch(chatControllerProvider).getUserChatsStream(userId);
  } catch (e) {
    debugPrint('Error in userChatsProvider: $e');
    return Stream.value([]);
  }
});

// Provider for a specific chat
final chatByIdProvider = StreamProvider.family<ChatModel?, String>((ref, chatId) {
  return ref.watch(chatControllerProvider).getChatStream(chatId);
});

// Provider to get or create a chat between two users
final chatBetweenUsersProvider = AutoDisposeFutureProvider.family<ChatModel?, Map<String, String>>((ref, params) async {
  try {
    final currentUserId = params['currentUserId']!;
    final otherUserId = params['otherUserId']!;
    
    debugPrint('Looking up chat between $currentUserId and $otherUserId');
    
    // Handle the case when either userIds are empty
    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      debugPrint('One of the user IDs is empty, returning null');
      return null;
    }
    
    // This provider will be auto-disposed when no longer used
    ref.onDispose(() {
      debugPrint('Disposing chat lookup between $currentUserId and $otherUserId');
    });
    
    return await ref.watch(chatControllerProvider).getChatByUsers(currentUserId, otherUserId);
  } catch (e) {
    debugPrint('Error in chatBetweenUsersProvider: $e');
    return null;
  }
}); 