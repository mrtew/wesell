import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/address_model.dart';
import '../models/user_model.dart';

class AddressController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all addresses for a user
  Future<List<AddressModel>> getAddresses(String userId) async {
    try {
      // Get user document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return [];
      }

      // Get addresses from user data
      UserModel user = UserModel.fromFirestore(userDoc);
      
      List<Map<String, dynamic>> addressMaps = user.addresses;
      
      List<AddressModel> addresses = [];
      
      // Convert address maps to AddressModel objects
      for (var i = 0; i < addressMaps.length; i++) {
        Map<String, dynamic> addressData = Map<String, dynamic>.from(addressMaps[i]);
        addresses.add(AddressModel.fromMap(addressData, i.toString()));
      }
      return addresses;
    } catch (e) {
      print('Error getting addresses: $e');
      return [];
    }
  }

  // Add a new address
  Future<bool> addAddress({
    required String userId,
    required String recipientName,
    required String recipientPhone,
    required String address,
    required String city,
    required String postalCode,
    required String state,
    required String country,
    required String note,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Get user document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return false;
      }

      // Get current user data
      UserModel user = UserModel.fromFirestore(userDoc);
      List<Map<String, dynamic>> addresses = user.addresses;
      
      // Check if this is the first address (set as default)
      bool isDefault = addresses.isEmpty;
      
      // Create new address
      Map<String, dynamic> newAddress = {
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'address': address,
        'city': city,
        'postalCode': postalCode,
        'state': state,
        'country': country,
        'note': note,
        'isDefault': isDefault,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': Timestamp.now(),
      };
      
      // Add new address to list - DON'T convert values to strings
      addresses.add(newAddress);
      
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'addresses': addresses,
        'updatedAt': Timestamp.now(),
      });
      
      return true;
    } catch (e) {
      print('Error adding address: $e');
      return false;
    }
  }

  // Edit an existing address
  Future<bool> editAddress({
    required String userId,
    required int addressIndex,
    required String recipientName,
    required String recipientPhone,
    required String address,
    required String city,
    required String postalCode,
    required String state,
    required String country,
    required String note,
    required bool isDefault,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Get user document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return false;
      }

      // Get current user data
      UserModel user = UserModel.fromFirestore(userDoc);
      List<Map<String, dynamic>> addresses = user.addresses;
      
      if (addressIndex >= addresses.length) {
        return false;
      }
      
      // Update address
      Map<String, dynamic> updatedAddress = {
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'address': address,
        'city': city,
        'postalCode': postalCode,
        'state': state,
        'country': country,
        'note': note,
        'isDefault': isDefault,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': addresses[addressIndex]['createdAt'] ?? Timestamp.now(),
      };
      
      // Update address in list - DON'T convert values to strings
      addresses[addressIndex] = updatedAddress;
      
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'addresses': addresses,
        'updatedAt': Timestamp.now(),
      });
      
      return true;
    } catch (e) {
      print('Error editing address: $e');
      return false;
    }
  }

  // Delete an address
  Future<bool> deleteAddress(String userId, int addressIndex) async {
    try {
      // Get user document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return false;
      }

      // Get current user data
      UserModel user = UserModel.fromFirestore(userDoc);
      List<Map<String, dynamic>> addresses = user.addresses;
      
      if (addressIndex >= addresses.length) {
        return false;
      }
      
      // Check if deleted address was default
      bool wasDefault = addresses[addressIndex]['isDefault'] == true;
      
      // Remove address
      addresses.removeAt(addressIndex);
      
      // If deleted address was default and there are other addresses, set a new default
      if (wasDefault && addresses.isNotEmpty) {
        addresses[0] = {...addresses[0], 'isDefault': true};
      }
      
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'addresses': addresses,
        'updatedAt': Timestamp.now(),
      });
      
      return true;
    } catch (e) {
      print('Error deleting address: $e');
      return false;
    }
  }

  // Set an address as default
  Future<bool> setDefaultAddress(String userId, int addressIndex) async {
    try {
      // Get user document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return false;
      }

      // Get current user data
      UserModel user = UserModel.fromFirestore(userDoc);
      List<Map<String, dynamic>> addresses = user.addresses;
      
      if (addressIndex >= addresses.length) {
        return false;
      }
      
      // Set all addresses to non-default
      for (int i = 0; i < addresses.length; i++) {
        addresses[i] = {...addresses[i], 'isDefault': false};
      }
      
      // Set selected address as default
      addresses[addressIndex] = {...addresses[addressIndex], 'isDefault': true};
      
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'addresses': addresses,
        'updatedAt': Timestamp.now(),
      });
      
      return true;
    } catch (e) {
      print('Error setting default address: $e');
      return false;
    }
  }
} 