import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_model.dart';
import '../models/user_model.dart';

class AdminController {
  final CollectionReference _adminsCollection = FirebaseFirestore.instance.collection('admins');
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Authenticate admin
  Future<AdminModel?> authenticateAdmin(String username, String password) async {
    try {
      // Query for admin with matching username
      QuerySnapshot query = await _adminsCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null; // No admin found with this username
      }

      // Get the admin document
      DocumentSnapshot adminDoc = query.docs.first;
      AdminModel admin = AdminModel.fromFirestore(adminDoc);

      // Verify password (in real app, use proper password hashing)
      if (admin.password == password) {
        return admin;
      }
      
      return null; // Password doesn't match
    } catch (e) {
      rethrow;
    }
  }

  // Get pending verification users
  Future<List<UserModel>> getPendingVerificationUsers({String? searchName}) async {
    try {
      // First get users that have identity verification pending
      // We can't directly query for non-empty maps in Firestore
      // So we'll get users where isIdentityVerified = false and filter in code
      Query query = _usersCollection
          .where('isIdentityVerified', isEqualTo: false)
          .orderBy('createdAt', descending: false);
      
      if (searchName != null && searchName.isNotEmpty) {
        // Add a filter for username (this is case-sensitive in Firestore)
        // Using startAt and endAt for a "contains" like query
        String searchEnd = searchName + '\uf8ff';
        query = query.where('username', isGreaterThanOrEqualTo: searchName)
                     .where('username', isLessThanOrEqualTo: searchEnd);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      // Filter users who have a non-empty identity map
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.identity.isNotEmpty) // Filter in Dart code
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Approve user verification
  Future<void> approveUserVerification(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'isIdentityVerified': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Reject user verification
  Future<void> rejectUserVerification(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'identity': {},
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }
}