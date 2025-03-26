import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wesell/controllers/auth_controller.dart';
import 'package:wesell/providers/auth_provider.dart';
import '../../widgets/app_bar_widget.dart';

class SettingScreen extends ConsumerStatefulWidget {
  const SettingScreen({super.key});

  @override
  ConsumerState<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends ConsumerState<SettingScreen> {
  final AuthController _authController = AuthController();
  
  // @override
  // void initState() {
  //   super.initState();
  //   // Add any initialization logic here
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Setting',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.grey[200],
            ),
            ListTile(
              title: const Text('Profile'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              onTap: () {
                GoRouter.of(context).push('/profile');
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
            ListTile(
              title: const Text('Logout'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              onTap: () {
                _authController.signOut();
                ref.read(verificationIdProvider.notifier).state = null;
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
      ),
    );
  }
} 