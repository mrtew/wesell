import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wesell/views/balance/balance_screen.dart';
import 'package:wesell/views/identity/verification_method_screen.dart';
import 'package:wesell/views/payment/address_confirm_screen.dart';
import 'package:wesell/views/payment/card_payment_screen.dart';
import 'package:wesell/views/payment/payment_failed_screen.dart';
import 'package:wesell/views/payment/payment_method_screen.dart';
import 'package:wesell/views/payment/payment_success_screen.dart';
import 'package:wesell/views/payment/verify_pin_screen.dart';
import 'package:wesell/views/pin/new_pin_1_screen.dart';
import 'package:wesell/views/pin/new_pin_2_screen.dart';
import 'package:wesell/views/pin/old_pin_screen.dart';
import '../views/auth/login_screen.dart';
import '../views/home/home_screen.dart';
import '../views/item/post_item_screen.dart';
import '../views/item/item_detail_screen.dart';
import '../views/item/edit_item_screen.dart';
import '../views/chat/chat_screen.dart';
import '../views/chat/chat_detail_screen.dart';
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
import '../views/items/item_posted_screen.dart';
import '../views/items/item_purchased_screen.dart';
import '../views/items/item_sold_screen.dart';
import '../views/admin/admin_login_screen.dart';
import '../views/admin/admin_home_screen.dart';
import '../views/admin/user_list_screen.dart';
import '../views/admin/verify_user_screen.dart';
import '../views/search/text_search_screen.dart';
import '../views/search/image_search_screen.dart';
import '../providers/admin_provider.dart';

// GoRouter Provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authUserProvider);
  final adminState = ref.watch(adminAuthProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      // Get auth states
      final isLoggedIn = authState.when(
        data: (user) => user != null,
        loading: () => false,
        error: (_, __) => false,
      );

      final isAdminLoggedIn = adminState != null;
      final path = state.uri.path;

      // Simple debug
      print(
        'Navigation path: $path, Admin: $isAdminLoggedIn, User: $isLoggedIn',
      );

      // Rule 1: Admin routes
      if (path.startsWith('/admin/')) {
        // If going to admin login, no redirection needed
        if (path == '/admin/login') {
          return null;
        }

        // If not admin and trying to access admin routes, redirect to admin login
        if (!isAdminLoggedIn) {
          return '/admin/login';
        }

        // Admin is logged in and accessing admin routes - allow
        return null;
      }

      // Rule 2: User authentication
      if (path == '/login') {
        // If admin is logged in, redirect to admin home
        if (isAdminLoggedIn) {
          return '/admin/home';
        }

        // If user is logged in, redirect to home
        if (isLoggedIn) {
          return '/home';
        }

        // Not logged in and trying to access login - allow
        return null;
      }

      // Rule 3: Protected routes
      if (!isLoggedIn && !path.startsWith('/admin/')) {
        return '/login';
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
          return MaterialPage(child: const PostItemScreen());
        },
      ),
      GoRoute(
        path: '/item/:id',
        name: 'item_detail',
        builder: (context, state) {
          final itemId = state.pathParameters['id']!;
          return ItemDetailScreen(itemId: itemId);
        },
      ),
      GoRoute(
        path: '/item/:id/edit',
        name: 'edit_item',
        builder: (context, state) {
          final itemId = state.pathParameters['id']!;
          return EditItemScreen(itemId: itemId);
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
        path: '/chat/new/:sellerId',
        name: 'new_chat',
        builder: (context, state) {
          final sellerId = state.pathParameters['sellerId']!;
          // Use a unique ValueKey based on the sellerId to ensure a new widget is created
          return ChatDetailScreen(
            sellerId: sellerId,
            key: ValueKey('chat_new_$sellerId'),
          );
        },
      ),
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat_detail',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          // Use a unique ValueKey based on the chatId to ensure a new widget is created
          return ChatDetailScreen(
            chatId: chatId,
            key: ValueKey('chat_detail_$chatId'),
          );
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
        path:
            '/add_address/:city/:postalCode/:state/:country/:latitude/:longitude',
        name: 'add_address',
        pageBuilder: (context, state) {
          return MaterialPage(
            child: AddAddressScreen(
              city: state.pathParameters['city'],
              postalCode: state.pathParameters['postalCode'],
              state_: state.pathParameters['state'],
              country: state.pathParameters['country'],
              latitude: double.tryParse(
                state.pathParameters['latitude'] ?? '0',
              ),
              longitude: double.tryParse(
                state.pathParameters['longitude'] ?? '0',
              ),
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
      // Payment Routes
      // Success and Failed screens first (most specific routes)
      GoRoute(
        path: '/payment/success',
        name: 'payment_success',
        builder: (context, state) {
          final paymentData = state.extra as Map<String, dynamic>;
          return PaymentSuccessScreen(paymentData: paymentData);
        },
      ),
      GoRoute(
        path: '/payment/failed',
        name: 'payment_failed',
        builder: (context, state) {
          final itemId = state.extra as String;
          return PaymentFailedScreen(itemId: itemId);
        },
      ),
      // Then item-specific routes
      // GoRoute(
      //   path: '/payment/:itemId/card_payment',
      //   name: 'card_payment',
      //   builder: (context, state) {
      //     final itemId = state.pathParameters['itemId']!;
      //     final deliveryAddress = state.extra as Map<String, dynamic>;
      //     return CardPaymentScreen(
      //       itemId: itemId,
      //       deliveryAddress: deliveryAddress,
      //     );
      //   },
      // ),
      GoRoute(
        path: '/payment/:itemId/card_payment',
        name: 'card_payment',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final paymentData = state.extra as Map<String, dynamic>;
          return CardPaymentScreen(
            itemId: itemId,
            paymentData: paymentData,
          );
        },
      ),
      GoRoute(
        path: '/payment/:itemId/verify_pin',
        name: 'verify_pin',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final paymentData = state.extra as Map<String, dynamic>;
          return VerifyPinScreen(itemId: itemId, paymentData: paymentData);
        },
      ),
      GoRoute(
        path: '/payment/:itemId/address_confirm',
        name: 'address_confirm',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final paymentMethod = state.extra as String;
          return AddressConfirmScreen(
            itemId: itemId,
            paymentMethod: paymentMethod,
          );
        },
      ),
      // Most general route last
      GoRoute(
        path: '/payment/:itemId',
        name: 'payment_method',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return PaymentMethodScreen(itemId: itemId);
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
      GoRoute(
        path: '/items_post',
        name: 'items_post',
        pageBuilder: (context, state) {
          return MaterialPage(child: const ItemPostedScreen());
        },
      ),
      GoRoute(
        path: '/items_purchased',
        name: 'items_purchased',
        pageBuilder: (context, state) {
          return MaterialPage(child: const ItemPurchasedScreen());
        },
      ),
      GoRoute(
        path: '/items_sold',
        name: 'items_sold',
        pageBuilder: (context, state) {
          return MaterialPage(child: const ItemSoldScreen());
        },
      ),
      // Admin routes
      GoRoute(
        path: '/admin/login',
        name: 'admin_login',
        pageBuilder: (context, state) {
          return MaterialPage(child: const AdminLoginScreen());
        },
      ),
      GoRoute(
        path: '/admin/home',
        name: 'admin_home',
        pageBuilder: (context, state) {
          return MaterialPage(child: const AdminHomeScreen());
        },
      ),
      GoRoute(
        path: '/admin/users',
        name: 'admin_users',
        pageBuilder: (context, state) {
          return MaterialPage(child: const UserListScreen());
        },
      ),
      GoRoute(
        path: '/admin/verify/:userId',
        name: 'verify_user',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return MaterialPage(child: VerifyUserScreen(userId: userId));
        },
      ),
      // Search routes
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          return MaterialPage(child: TextSearchScreen(initialQuery: query));
        },
      ),
      GoRoute(
        path: '/search/image',
        name: 'image_search',
        pageBuilder: (context, state) {
          final imageFile = state.extra as File;
          return MaterialPage(child: ImageSearchScreen(imageFile: imageFile));
        },
      ),
    ],
    // Error page
    errorBuilder:
        (context, state) =>
            Scaffold(body: Center(child: Text('Error: ${state.error}'))),
  );
});
