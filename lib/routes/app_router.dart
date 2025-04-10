import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wesell/views/balance/balance_screen.dart';
import 'package:wesell/views/identity/verification_method_screen.dart';
import 'package:wesell/views/pin/new_pin_1_screen.dart';
import 'package:wesell/views/pin/new_pin_2_screen.dart';
import 'package:wesell/views/pin/old_pin_screen.dart';
import '../views/auth/login_screen.dart';
import '../views/home/home_screen.dart';
import '../views/item/item_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/me/edit_username_screen.dart';
import '../views/me/edit_avatar_screen.dart';
import '../views/me/me_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../views/me/profile_screen.dart';
import '../views/me/setting_screen.dart';
import '../views/addresses/addresses_screen.dart';
import '../views/addresses/open_map_screen.dart';
import '../views/addresses/add_address_screen.dart';
import '../views/addresses/edit_address_screen.dart';
import '../views/identity/mykad_verification_screen.dart';
import '../views/identity/passport_verification_screen.dart';

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
        path: '/edit_avatar',
        name: 'edit_avatar',
        pageBuilder: (context, state) {
          return MaterialPage(child: const EditAvatarScreen());
        },
      ),
      GoRoute(
        path: '/setting',
        name: 'setting',
        pageBuilder: (context, state) {
          return MaterialPage(child: const SettingScreen());
        },
      ),
      GoRoute(
        path: '/addresses',
        name: 'addresses',
        pageBuilder: (context, state) {
          return MaterialPage(child: const AddressesScreen());
        },
      ),
      GoRoute(
        path: '/open_map',
        name: 'open_map',
        pageBuilder: (context, state) {
          return MaterialPage(child: const OpenMapScreen());
        },
      ),
      GoRoute(
        path: '/add_address/:city/:postalCode/:state/:country/:latitude/:longitude',
        name: 'add_address',
        pageBuilder: (context, state) {
          return MaterialPage(
            child: AddAddressScreen(
              city: state.pathParameters['city'],
              postalCode: state.pathParameters['postalCode'],
              state_: state.pathParameters['state'],
              country: state.pathParameters['country'],
              latitude: double.tryParse(state.pathParameters['latitude'] ?? '0'),
              longitude: double.tryParse(state.pathParameters['longitude'] ?? '0'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/edit_address',
        name: 'edit_address',
        pageBuilder: (context, state) {
          return MaterialPage(child: const EditAddressScreen());
        },
      ),
      GoRoute(
        path: '/new_pin_1',
        name: 'new_pin_1',
        pageBuilder: (context, state) {
          return MaterialPage(child: const NewPin1Screen());
        },
      ),
      GoRoute(
        path: '/new_pin_2',
        name: 'new_pin_2',
        pageBuilder: (context, state) {
          final pin = state.extra as String;
          return MaterialPage(child: NewPin2Screen(pin: pin));
        },
      ),
      GoRoute(
        path: '/old_pin',
        name: 'old_pin',
        pageBuilder: (context, state) {
          return MaterialPage(child: const OldPinScreen());
        },
      ),
      GoRoute(
        path: '/balance',
        name: 'balance',
        pageBuilder: (context, state) {
          return MaterialPage(child: const BalanceScreen());
        },
      ),
      GoRoute(
        path: '/verification_method',
        name: 'verification_method',
        pageBuilder: (context, state) {
          return MaterialPage(child: const VerificationMethodScreen());
        },
      ),
      GoRoute(
        path: '/mykad_verification',
        name: 'mykad_verification',
        pageBuilder: (context, state) {
          return MaterialPage(child: const MyKadVerificationScreen());
        },
      ),
      GoRoute(
        path: '/passport_verification',
        name: 'passport_verification',
        pageBuilder: (context, state) {
          return MaterialPage(child: const PassportVerificationScreen());
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