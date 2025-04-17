import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../models/item_model.dart';

class ItemController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CollectionReference _itemsCollection = 
      FirebaseFirestore.instance.collection('items');
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  // Create a new item
  Future<String> createItem({
    required String sellerId,
    required String title,
    required String description,
    required String category,
    required double originalPrice,
    required double price,
    required List<File> imageFiles,
  }) async {
    try {
      // Convert prices to integers (storing in smallest currency unit, e.g., cents)
      final int originalPriceInt = (originalPrice * 100).round();
      final int priceInt = (price * 100).round();
      
      // Upload images and get download URLs
      List<String> imageUrls = await _uploadImages(sellerId, imageFiles);
      
      // Extract image metadata for future image search feature
      Map<String, dynamic> imageMetadata = await _extractImageMetadata(imageFiles);
      
      // Create new item
      final ItemModel newItem = ItemModel(
        sellerId: sellerId,
        title: title,
        description: description,
        category: category,
        originalPrice: originalPriceInt,
        price: priceInt,
        images: imageUrls,
        status: 'available',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        imageMetadata: imageMetadata,
      );
      
      // Save to Firestore
      DocumentReference docRef = await _itemsCollection.add(newItem.toMap());
      
      // Update user's itemsPosted array and role to 'seller'
      await _firestore.collection('users').doc(sellerId).update({
        'itemsPosted': FieldValue.arrayUnion([docRef.id]),
        'role': 'seller',
      });
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create item: $e');
    }
  }
  
  // Upload images to Firebase Storage
  Future<List<String>> _uploadImages(String sellerId, List<File> imageFiles) async {
    List<String> imageUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      File imageFile = imageFiles[i];
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      String path = 'items/$sellerId/$fileName';
      
      try {
        // Upload image to Firebase Storage
        TaskSnapshot taskSnapshot = await _storage.ref(path).putFile(imageFile);
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        throw Exception('Failed to upload image: $e');
      }
    }
    
    return imageUrls;
  }
  
  // Extract metadata from images using Google ML Kit
  Future<Map<String, dynamic>> _extractImageMetadata(List<File> imageFiles) async {
    Map<String, dynamic> metadata = {};
    
    try {
      // Use the first image as the primary image for metadata extraction
      if (imageFiles.isNotEmpty) {
        final InputImage inputImage = InputImage.fromFile(imageFiles[0]);
        
        // Initialize image labeler with default model
        final ImageLabeler imageLabeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.7),
        );
        
        // Process the image to get labels
        final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
        
        // Extract and store labels with confidence scores
        List<Map<String, dynamic>> extractedLabels = [];
        for (ImageLabel label in labels) {
          extractedLabels.add({
            'text': label.label,
            'confidence': label.confidence,
            'index': label.index,
          });
        }
        
        // Add labels to metadata
        metadata['labels'] = extractedLabels;
        
        // Close labeler when done
        imageLabeler.close();
        
        // If there are multiple images, process them too 
        // but limit to first 3 to avoid excessive processing
        if (imageFiles.length > 1) {
          List<Map<String, dynamic>> additionalImagesLabels = [];
          
          for (int i = 1; i < imageFiles.length && i < 3; i++) {
            final additionalImage = InputImage.fromFile(imageFiles[i]);
            final additionalLabeler = ImageLabeler(
              options: ImageLabelerOptions(confidenceThreshold: 0.7),
            );
            
            final additionalLabels = await additionalLabeler.processImage(additionalImage);
            
            List<Map<String, dynamic>> imageLabels = [];
            for (ImageLabel label in additionalLabels) {
              imageLabels.add({
                'text': label.label,
                'confidence': label.confidence,
                'index': label.index,
              });
            }
            
            additionalImagesLabels.add({
              'imageIndex': i,
              'labels': imageLabels,
            });
            
            additionalLabeler.close();
          }
          
          metadata['additionalImagesLabels'] = additionalImagesLabels;
        }
      }
    } catch (e) {
      // If extraction fails, just log and continue without metadata
      print('Failed to extract image metadata: $e');
    }
    
    return metadata;
  }

  // Get item by ID
  Future<ItemModel?> getItemById(String itemId) async {
    try {
      DocumentSnapshot doc = await _itemsCollection.doc(itemId).get();
      if (doc.exists) {
        return ItemModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get item: $e');
    }
  }
  
  // Delete an item
  Future<void> deleteItem(String itemId) async {
    try {
      // Get the item to retrieve its images and seller
      DocumentSnapshot doc = await _itemsCollection.doc(itemId).get();
      if (!doc.exists) {
        throw Exception('Item not found');
      }
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String sellerId = data['sellerId'];
      // List<String> imageUrls = List<String>.from(data['images']);
      
      // // Delete images from storage
      // for (String imageUrl in imageUrls) {
      //   try {
      //     // Extract the storage reference from the URL
      //     // Firebase storage URLs have a format like:
      //     // https://firebasestorage.googleapis.com/v0/b/[PROJECT_ID].appspot.com/o/[PATH]?alt=media&token=[TOKEN]
      //     Uri uri = Uri.parse(imageUrl);
      //     String path = Uri.decodeComponent(uri.path.split('/o/')[1]);
      //     await _storage.ref(path).delete();
      //   } catch (e) {
      //     // Log error but continue with deletion process
      //     print('Error deleting image: $e');
      //   }
      // }
      
      // Update user's itemsPosted array
      await _usersCollection.doc(sellerId).update({
        'itemsPosted': FieldValue.arrayRemove([itemId]),
      });
      
      // Soft delete by updating status to 'deleted' and setting deletedAt timestamp
      await _itemsCollection.doc(itemId).update({
        'status': 'deleted',
        'deletedAt': Timestamp.now(),
      });
      
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }
  
  // Update an existing item
  Future<void> updateItem({
    required String itemId,
    required String title,
    required String description,
    required String category,
    required double originalPrice,
    required double price,
    List<File>? newImages,
    List<String>? removedImageUrls,
    List<String>? existingImageUrls,
  }) async {
    try {
      // Get the existing item
      DocumentSnapshot doc = await _itemsCollection.doc(itemId).get();
      if (!doc.exists) {
        throw Exception('Item not found');
      }
      
      // Convert prices to integers (storing in smallest currency unit, e.g., cents)
      final int originalPriceInt = (originalPrice * 100).round();
      final int priceInt = (price * 100).round();
      
      // Get seller ID from existing item
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String sellerId = data['sellerId'];
      
      // Process images
      List<String> finalImageUrls = [];
      
      // Add existing images that weren't removed
      if (existingImageUrls != null && existingImageUrls.isNotEmpty) {
        finalImageUrls.addAll(existingImageUrls);
      }
      
      // Delete removed images from storage
      // if (removedImageUrls != null && removedImageUrls.isNotEmpty) {
      //   for (String imageUrl in removedImageUrls) {
      //     try {
      //       // Extract the storage reference from the URL
      //       Uri uri = Uri.parse(imageUrl);
      //       String path = Uri.decodeComponent(uri.path.split('/o/')[1]);
      //       await _storage.ref(path).delete();
      //     } catch (e) {
      //       // Log error but continue with update process
      //       print('Error deleting removed image: $e');
      //     }
      //   }
      // }
      
      // Upload new images
      if (newImages != null && newImages.isNotEmpty) {
        List<String> newImageUrls = await _uploadImages(sellerId, newImages);
        finalImageUrls.addAll(newImageUrls);
      }
      
      // Update item in Firestore
      await _itemsCollection.doc(itemId).update({
        'title': title,
        'description': description,
        'category': category,
        'originalPrice': originalPriceInt,
        'price': priceInt,
        'images': finalImageUrls,
        'updatedAt': Timestamp.now(),
      });
      
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }
} 