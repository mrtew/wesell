import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_model.dart';
import '../models/user_model.dart';
import '../controllers/admin_controller.dart';

// Admin authentication state provider
final adminAuthProvider = StateProvider<AdminModel?>((ref) => null);

// Provider for pending verification users
final pendingVerificationUsersProvider = 
    StateNotifierProvider<PendingVerificationUsersNotifier, AsyncValue<List<UserModel>>>((ref) {
  return PendingVerificationUsersNotifier(ref, AdminController());
});

// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Notifier for pending verification users
class PendingVerificationUsersNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final Ref _ref;
  final AdminController _adminController;
  
  PendingVerificationUsersNotifier(this._ref, this._adminController) 
      : super(const AsyncValue.loading()) {
    fetchUsers();
  }
  
  Future<void> fetchUsers() async {
    try {
      state = const AsyncValue.loading();
      final searchQuery = _ref.read(searchQueryProvider);
      final users = await _adminController.getPendingVerificationUsers(
        searchName: searchQuery.isNotEmpty ? searchQuery : null
      );
      state = AsyncValue.data(users);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  // Update search query and refresh users
  Future<void> updateSearchQuery(String query) async {
    _ref.read(searchQueryProvider.notifier).state = query;
    await fetchUsers();
  }
}