import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';

// Provider for AuthController
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

// Provider for current Firebase User
final authUserProvider = StreamProvider<User?>((ref) {
  final authController = ref.watch(authControllerProvider);
  return authController.authStateChanges;
});

// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authUserProvider);
  return authState.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Provider for verification ID during phone auth
final verificationIdProvider = StateProvider<String?>((ref) => null);

// Provider for handling phone auth verification state
enum VerificationState { initial, codeSent, verified, error }

// Provider for phone number verification state
final verificationStateProvider = StateProvider<VerificationState>((ref) {
  return VerificationState.initial;
});

// Provider for auth error messages
final authErrorProvider = StateProvider<String?>((ref) => null); 