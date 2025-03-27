import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../views/auth/login_screen.dart';
import '../views/home/home_screen.dart';
import '../views/item/item_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/me/edit_username.dart';
import '../views/me/me_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../views/me/profile_screen.dart';
import '../views/me/setting_screen.dart';

// GoRouter Provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authUserProvider);
  
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      // Get auth state
      final isLoggedIn = authState.when(
        data: (user) => user != null,
        loading: () => false,
        error: (_, __) => false,
      );
      
      final isGoingToLogin = state.uri.path == '/login';
      
      // If not logged in and not going to login page, redirect to login
      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }
      
      // If logged in and going to login page, redirect to home
      if (isLoggedIn && isGoingToLogin) {
        return '/home';
      }
      
      // No redirection needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) {
          // Schedule the state update after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentTabProvider.notifier).state = 0;
          });
          return MaterialPage(child: const HomeScreen());
        },
      ),
      GoRoute(
        path: '/item',
        name: 'item',
        pageBuilder: (context, state) {
          // Schedule the state update after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentTabProvider.notifier).state = 1;
          });
          return MaterialPage(child: const ItemScreen());
        },
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) {
          // Schedule the state update after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentTabProvider.notifier).state = 2;
          });
          return MaterialPage(child: const ChatScreen());
        },
      ),
      GoRoute(
        path: '/me',
        name: 'me',
        pageBuilder: (context, state) {
          // Schedule the state update after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentTabProvider.notifier).state = 3;
          });
          return MaterialPage(child: const MeScreen());
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) {
          return MaterialPage(child: const ProfileScreen());
        },
      ),
      GoRoute(
        path: '/edit_username',
        name: 'edit_username',
        pageBuilder: (context, state) {
          return MaterialPage(child: const EditUsernameScreen());
        },
      ),
      GoRoute(
        path: '/setting',
        name: 'setting',
        pageBuilder: (context, state) {
          return MaterialPage(child: const SettingScreen());
        },
      ),
    ],
    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}); 