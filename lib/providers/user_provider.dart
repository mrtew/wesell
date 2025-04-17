import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:wesell/models/user_model.dart';
import '../controllers/user_controller.dart';
import 'auth_provider.dart';

// Provider for UserController
final userControllerProvider = Provider<UserController>((ref) {
  return UserController();
});

// Provider for the current user data
// final currentUserProvider = FutureProvider<UserModel?>((ref) async {
final currentUserProvider = FutureProvider.autoDispose<dynamic>((ref) async {
  final authState = ref.watch(authUserProvider);
  final userController = ref.watch(userControllerProvider);
  
  return authState.when(
    data: (user) async {
      if (user != null) {
        return await userController.getUserById(user.uid);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Provider for user loading state
final userLoadingProvider = StateProvider<bool>((ref) => false);

// Provider for user error messages
final userErrorProvider = StateProvider<String?>((ref) => null);

// Cache for seller information to prevent repeated fetches
final sellerCacheProvider = StateProvider<Map<String, dynamic>>((ref) => {});

// Provider to get seller by ID with caching
final sellerByIdProvider = FutureProvider.family<dynamic, String>((ref, sellerId) async {
  // Check if seller data is already cached
  final cache = ref.watch(sellerCacheProvider);
  if (cache.containsKey(sellerId)) {
    return cache[sellerId];
  }
  
  // If not cached, fetch from database
  final userController = ref.read(userControllerProvider);
  final seller = await userController.getUserById(sellerId);
  
  // Add to cache if seller was found
  if (seller != null) {
    ref.read(sellerCacheProvider.notifier).update((state) => {
      ...state,
      sellerId: seller,
    });
  }
  
  return seller;
}); 