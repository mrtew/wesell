import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_bar_widget.dart';
import '../../providers/user_provider.dart';
import '../../widgets/cached_avatar_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
  }

  @override
  Widget build(BuildContext context) {   
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Profile',
        showBackButton: true,
      ),
      body: ref.watch(currentUserProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (user) {        
          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Photo Section
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
                ListTile(
                  title: const Text('Profile Photo'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User avatar
                      CachedAvatarWidget(
                        avatarUrl: user?.avatar,
                        width: 40,
                        height: 40,
                        borderRadius: 4,
                        iconSize: 24,
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  onTap: () {
                    GoRouter.of(context).push('/edit_avatar');
                  },
                  tileColor: Colors.white,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
                
                // Name Section
                ListTile(
                  title: const Text('Name'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User name
                      Text(
                        user?.username,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  onTap: () {
                    GoRouter.of(context).push('/edit_username');
                  },
                  tileColor: Colors.white,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 