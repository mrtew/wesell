import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/navigation_provider.dart';

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          // Set the current tab index
          // ref.read(currentTabProvider.notifier).state = index;
          
          // Navigate to the corresponding path
          context.go(getPathForIndex(index));
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
              color: currentIndex == 0 ? Colors.green : Colors.grey,
            ),
            activeIcon: const Icon(
              Icons.home,
              color: Colors.green,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.category_outlined,
              color: currentIndex == 1 ? Colors.green : Colors.grey,
            ),
            activeIcon: const Icon(
              Icons.category,
              color: Colors.green,
            ),
            label: 'Item',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.chat_bubble_outline,
              color: currentIndex == 2 ? Colors.green : Colors.grey,
            ),
            activeIcon: const Icon(
              Icons.chat_bubble,
              color: Colors.green,
            ),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline,
              color: currentIndex == 3 ? Colors.green : Colors.grey,
            ),
            activeIcon: const Icon(
              Icons.person,
              color: Colors.green,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
} 