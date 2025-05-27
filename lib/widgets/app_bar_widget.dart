import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import '../providers/navigation_provider.dart';

class AppBarWidget extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final String path;

  const AppBarWidget({
    super.key,
    required this.title,
    required this.showBackButton,
    this.path = '/home',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      leading: showBackButton ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () {
          // Navigate to home tab
          // ref.read(currentTabProvider.notifier).state = 0;
          // context.go(path);
          GoRouter.of(context).pop();
        },
      ) : null,
      // actions: [
      //   IconButton(
      //     icon: const Icon(Icons.search),
      //     onPressed: () {
      //       // Search action
      //     },
      //   ),
      //   IconButton(
      //     icon: const Icon(Icons.add),
      //     onPressed: () {
      //       // Add action
      //     },
      //   ),
      // ],
      elevation: 1,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 