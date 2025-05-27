import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/chat_model.dart';
import '../controllers/user_controller.dart';

class ChatController {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final UserController _userController;
  final Ref _ref;

  ChatController(this._firestore, this._storage, this._userController, this._ref);

  // Get a stream of chats for the current user
  Stream<List<ChatModel>> getUserChatsStream(String userId) {
    try {
      // Create a stream transformer that combines both queries
      return _firestore.collection('chats').snapshots().map((snapshot) {
        // Filter the documents to find both sender and receiver chats
        final chats = snapshot.docs
            .where((doc) {
              final data = doc.data();
              return (data['userIds']['sender'] == userId || 
                     data['userIds']['receiver'] == userId);
            })
            .map((doc) => ChatModel.fromFirestore(doc))
            .toList();
        
        // Sort by updatedAt timestamp (most recent first)
        chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        
        debugPrint('Retrieved ${chats.length} chats for user $userId');
        return chats;
      });
    } catch (e) {
      debugPrint('Error creating getUserChatsStream: $e');
      // Return an empty stream instead of throwing
      return Stream.value([]);
    }
  }

  // Get a single chat by its ID
  Stream<ChatModel?> getChatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? ChatModel.fromFirestore(doc) : null);
  }

  // Get chat by seller ID and buyer ID
  Future<ChatModel?> getChatByUsers(String currentUserId, String otherUserId) async {
    try {
      debugPrint('Finding chat between users: $currentUserId and $otherUserId');
      
      // First query: check if currentUser is sender
      final query = await _firestore
          .collection('chats')
          .where('userIds.sender', isEqualTo: currentUserId)
          .where('userIds.receiver', isEqualTo: otherUserId)
          .get();

      if (query.docs.isNotEmpty) {
        debugPrint('Found chat as sender: ${query.docs.first.id}');
        return ChatModel.fromFirestore(query.docs.first);
      }

      // Second query: check if currentUser is receiver
      final reverseQuery = await _firestore
          .collection('chats')
          .where('userIds.sender', isEqualTo: otherUserId)
          .where('userIds.receiver', isEqualTo: currentUserId)
          .get();

      if (reverseQuery.docs.isNotEmpty) {
        debugPrint('Found chat as receiver: ${reverseQuery.docs.first.id}');
        return ChatModel.fromFirestore(reverseQuery.docs.first);
      }

      debugPrint('No existing chat found between these users');
      return null;
    } catch (e) {
      debugPrint('Error in getChatByUsers: $e');
      return null;
    }
  }

  // Send a text message
  Future<void> sendTextMessage(String currentUserId, String receiverId, String message) async {
    // Check if a chat already exists between these users
    ChatModel? existingChat = await getChatByUsers(currentUserId, receiverId);
    
    final timestamp = Timestamp.now();
    
    if (existingChat != null) {
      // Add message to existing chat
      List<Map<String, dynamic>> updatedMessages = List.from(existingChat.messages);
      updatedMessages.add({
        'type': 'text',
        'content': message,
        'senderId': currentUserId,
        'timestamp': timestamp,
      });
      
      // Update the chat document
      await _firestore.collection('chats').doc(existingChat.id).update({
        'messages': updatedMessages,
        'updatedAt': timestamp,
      });
    } else {
      // Create a new chat
      final newChat = {
        'userIds': {
          'sender': currentUserId,
          'receiver': receiverId,
        },
        'messages': [
          {
            'type': 'text',
            'content': message,
            'senderId': currentUserId,
            'timestamp': timestamp,
          }
        ],
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      
      // Add new chat document
      DocumentReference chatRef = await _firestore.collection('chats').add(newChat);
      
      // Update both users' chat lists
      await _userController.addChatToUser(currentUserId, chatRef.id);
      await _userController.addChatToUser(receiverId, chatRef.id);
    }
  }

  // Send an image message
  Future<void> sendImageMessage(String currentUserId, String receiverId, XFile imageFile) async {
    try {
      // Check if a chat already exists first to get the chat ID for storage path
      ChatModel? existingChat = await getChatByUsers(currentUserId, receiverId);
      String chatId;
      
      if (existingChat == null) {
        // If no chat exists, we'll need to create one with an empty messages array
        // to get a chat ID for the storage path
        final timestamp = Timestamp.now();
        final newChat = {
          'userIds': {
            'sender': currentUserId,
            'receiver': receiverId,
          },
          'messages': [],
          'createdAt': timestamp,
          'updatedAt': timestamp,
        };
        
        // Add new chat document to get an ID
        DocumentReference chatRef = await _firestore.collection('chats').add(newChat);
        chatId = chatRef.id;
        
        // Update both users' chat lists with the new chat
        await _userController.addChatToUser(currentUserId, chatId);
        await _userController.addChatToUser(receiverId, chatId);
      } else {
        chatId = existingChat.id;
      }
      
      // Compress the image
      final compressedImage = await _compressImage(imageFile);
      if (compressedImage == null) {
        throw Exception('Failed to compress image');
      }
      
      // Upload to Firebase Storage in the chats/{chatId} directory
      final fileName = '${const Uuid().v4()}${path.extension(imageFile.path)}';
      final storageRef = _storage.ref().child('chats/$chatId/$fileName');
      final uploadTask = storageRef.putFile(compressedImage);
      final snapshot = await uploadTask.whenComplete(() => null);
      
      // Get download URL
      final imageUrl = await snapshot.ref.getDownloadURL();
      
      final timestamp = Timestamp.now();
      
      // Now add the message to the chat
      if (existingChat != null) {
        // Add message to existing chat
        List<Map<String, dynamic>> updatedMessages = List.from(existingChat.messages);
        updatedMessages.add({
          'type': 'image',
          'content': imageUrl,
          'senderId': currentUserId,
          'timestamp': timestamp,
        });
        
        // Update the chat document
        await _firestore.collection('chats').doc(chatId).update({
          'messages': updatedMessages,
          'updatedAt': timestamp,
        });
      } else {
        // The chat was just created with an empty messages array, so update it
        await _firestore.collection('chats').doc(chatId).update({
          'messages': [
            {
              'type': 'image',
              'content': imageUrl,
              'senderId': currentUserId,
              'timestamp': timestamp,
            }
          ],
          'updatedAt': timestamp,
        });
      }
      
      debugPrint('Image successfully uploaded to chats/$chatId/$fileName');
      return;
    } catch (e) {
      debugPrint('Error sending image message: $e');
      rethrow;
    }
  }

  // Helper method to compress images
  Future<File?> _compressImage(XFile file) async {
    try {
      File inputFile = File(file.path);
      final bytes = await inputFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        return inputFile;
      }
      
      // Resize while maintaining aspect ratio
      // Set max dimension to 1024px while preserving aspect ratio
      int targetWidth = image.width;
      int targetHeight = image.height;
      double aspectRatio = image.width / image.height;
      
      if (image.width > 1024 || image.height > 1024) {
        if (image.width > image.height) {
          // Landscape image
          targetWidth = 1024;
          targetHeight = (targetWidth / aspectRatio).round();
        } else {
          // Portrait image
          targetHeight = 1024;
          targetWidth = (targetHeight * aspectRatio).round();
        }
        
        // Resize the image maintaining aspect ratio
        image = img.copyResize(
          image, 
          width: targetWidth,
          height: targetHeight,
        );
      }
      
      // Save to temporary file with good quality
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${path.basename(file.path)}';
      
      File resultFile = File(targetPath);
      await resultFile.writeAsBytes(img.encodeJpg(image, quality: 85)); // Higher quality
      
      return resultFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return File(file.path); // Return original if compression fails
    }
  }
} 