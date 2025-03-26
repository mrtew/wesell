import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserController {
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Create a new user
  Future<void> createUser(UserModel user) async {
    await _usersCollection.doc(user.uid).set(user.toMap());
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update user
  Future<void> updateUser(UserModel user) async {
    await _usersCollection.doc(user.uid).update(user.toMap());
  }

  // Check if user exists
  Future<bool> userExists(String userId) async {
    DocumentSnapshot doc = await _usersCollection.doc(userId).get();
    return doc.exists;
  }

  // Update user login timestamp
  Future<void> updateLoginTimestamp(String userId) async {
    await _usersCollection.doc(userId).update({
      'updatedAt': Timestamp.now(),
    });
  }

  // Get or create user
  Future<UserModel> getOrCreateUser(String userId, String phoneNumber) async {
    bool exists = await userExists(userId);
    
    if (exists) {
      // User exists, update timestamp
      await updateLoginTimestamp(userId);
      return (await getUserById(userId))!;
    } else {
      // Create a new user
      Timestamp now = Timestamp.fromDate(DateTime.now());

      UserModel newUser = UserModel(
        uid: userId,
        userId: userId,
        role: 'user',
        username: '',
        avatar: '',
        phoneNumber: phoneNumber,
        email: '',
        identity: {},
        isPhoneNumberVerified: true,
        isEmailVerified: false,
        isIdentityVerified: false,
        addresses: [],
        itemsPosted: [],
        itemsPurchased: [],
        itemsSold: [],
        chats: [],
        transactions: [],
        balance: 0.0,
        pin: 0,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await createUser(newUser);
      return newUser;
    }
  }
} 