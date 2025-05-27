import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'dart:io';
import '../models/item_model.dart';

class SearchController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _itemsCollection = FirebaseFirestore.instance.collection('items');

  // Search items by text (title or description)
  Future<List<ItemModel>> searchItemsByText(String searchText) async {
    try {
      if (searchText.isEmpty) {
        return [];
      }

      // Convert to lowercase for case-insensitive search
      String searchTextLower = searchText.toLowerCase();
      
      // Get all available items
      QuerySnapshot snapshot = await _itemsCollection
          .where('status', isEqualTo: 'available')
          .orderBy('createdAt', descending: true)
          .get();
      
      // Filter the items in Dart since Firestore doesn't support case-insensitive
      // text search with "contains" functionality
      List<ItemModel> matchedItems = snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) {
            String titleLower = item.title.toLowerCase();
            String descLower = item.description.toLowerCase();
            
            // Check if title or description contains the search text
            return titleLower.contains(searchTextLower) || 
                   descLower.contains(searchTextLower);
          })
          .toList();
      
      return matchedItems;
    } catch (e) {
      throw Exception('Failed to search items: $e');
    }
  }

  // Search items by image using ML Kit
  Future<List<ItemModel>> searchItemsByImage(File imageFile) async {
    try {
      // Extract labels from the uploaded image
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final ImageLabeler imageLabeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.7),
      );
      
      final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
      
      // Close the labeler when done
      imageLabeler.close();
      
      // If no labels were detected, return empty list
      if (labels.isEmpty) {
        return [];
      }
      
      // Get all available items
      QuerySnapshot snapshot = await _itemsCollection
          .where('status', isEqualTo: 'available')
          .orderBy('createdAt', descending: true)
          .get();
      
      // Extract label texts for easier comparison
      List<String> searchLabelTexts = labels.map((label) => label.label.toLowerCase()).toList();
      
      // Filter items based on matching labels in imageMetadata
      List<ItemModel> matchedItems = snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) {
            // Skip items without metadata
            if (item.imageMetadata == null) return false;
            
            // Get labels from item metadata
            List<dynamic>? itemLabels = item.imageMetadata!['labels'];
            if (itemLabels == null || itemLabels.isEmpty) return false;
            
            // Check if any of the item's labels match our search labels
            for (var itemLabel in itemLabels) {
              String labelText = itemLabel['text'].toString().toLowerCase();
              
              // If any label from the search image matches a label in this item
              if (searchLabelTexts.contains(labelText)) {
                return true;
              }
            }
            
            // Also check additional images if available
            List<dynamic>? additionalImagesLabels = 
                item.imageMetadata!['additionalImagesLabels'];
            
            if (additionalImagesLabels != null && additionalImagesLabels.isNotEmpty) {
              for (var additionalImage in additionalImagesLabels) {
                List<dynamic>? additionalLabels = additionalImage['labels'];
                
                if (additionalLabels != null) {
                  for (var label in additionalLabels) {
                    String labelText = label['text'].toString().toLowerCase();
                    
                    if (searchLabelTexts.contains(labelText)) {
                      return true;
                    }
                  }
                }
              }
            }
            
            return false;
          })
          .toList();
      
      return matchedItems;
    } catch (e) {
      throw Exception('Failed to search items by image: $e');
    }
  }
} 