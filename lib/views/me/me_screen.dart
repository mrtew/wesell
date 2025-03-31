import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_bar_widget.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(currentUserProvider));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Me',
        showBackButton: false,
      ),
      body: ref.watch(currentUserProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (user) {  
          return SafeArea(
            child: ListView(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
                // Profile Section
                GestureDetector(
                  onTap: () {
                    GoRouter.of(context).push('/profile');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Row(
                      children: [
                        // Profile Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: user?.avatar != ''
                              ? Image.network(
                                  user?.avatar ?? '',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[200],
                                      child: Icon(Icons.person, color: Colors.grey[400], size: 40),
                                    );
                                  },
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.person, color: Colors.grey[400], size: 40),
                                )
                        ),
                        // const SizedBox(width: 8),
                        // Container(
                        //   width: 60,
                        //   height: 60,
                        //   decoration: BoxDecoration(
                        //     borderRadius: BorderRadius.circular(8),
                        //     image: const DecorationImage(
                        //       image: AssetImage('assets/images/default_avatar_1024x1024.png'),
                        //       fit: BoxFit.cover,
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(width: 20),
                        // Profile Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user?.username}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'WeSell ID: ${user?.userId.substring(0, 14)}...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // QR Code Icon
                        // Icon(
                        //   Icons.qr_code,
                        //   size: 24,
                        //   color: Colors.grey[600],
                        // ),
                        // const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
                ListTile(
                  leading: const Icon(Icons.phone_iphone_rounded, color: Colors.blue),
                  title: const Text('Phone'),
                  // trailing: Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User name
                      Text(
                        '${user!.phoneNumber.substring(0, 6)}${'*' * (user.phoneNumber.length - 8)}${user.phoneNumber.substring(user.phoneNumber.length - 2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  // onTap: () {
                  //
                  // },
                  tileColor: Colors.white,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.grey[200],
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_rounded, color: Colors.blue),
                  title: const Text('My Addresses'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  onTap: () {
                    GoRouter.of(context).push('/addresses');
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
                // Settings Button
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.blue),
                  title: const Text('Setting'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  onTap: () {
                    GoRouter.of(context).push('/setting');
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
      bottomNavigationBar: const BottomNavBar(),
    );
  }
} 
