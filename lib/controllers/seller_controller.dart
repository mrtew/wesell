import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seller_model.dart';

class SellerController {
  final CollectionReference _sellersCollection = FirebaseFirestore.instance.collection('sellers');

  // Check if a seller record exists for a given userId
  Future<bool> sellerRecordExists(String userId) async {
    try {
      QuerySnapshot query = await _sellersCollection.where('userId', isEqualTo: userId).limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking seller record existence: $e');
      return false;
    }
  }

  // Create a new seller record
  Future<void> createSellerRecord(String userId) async {
    try {
      final Map<String, dynamic> sellerData = {
        'userId': userId,
        'createdAt': Timestamp.now(),
      };
      await _sellersCollection.add(sellerData);
    } catch (e) {
      print('Error creating seller record: $e');
      rethrow;
    }
  }
}