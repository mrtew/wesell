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