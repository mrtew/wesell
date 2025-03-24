import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_bar_widget.dart';

class ItemScreen extends ConsumerWidget {
  const ItemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Item',
        showBackButton: false,
      ),
      body: const Center(
        child: Text('Item Tab Content'),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
} 