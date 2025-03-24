import 'package:flutter_riverpod/flutter_riverpod.dart';

// Current tab index provider
final currentTabProvider = StateProvider<int>((ref) => 0);

// Tab paths in order of their indices
final tabPaths = ['/home', '/item', '/chat', '/profile'];

// Get the path for a given tab index
String getPathForIndex(int index) {
  if (index >= 0 && index < tabPaths.length) {
    return tabPaths[index];
  }
  return '/home';
}

// Get the index for a given path
int getIndexForPath(String path) {
  return tabPaths.contains(path) ? tabPaths.indexOf(path) : 0;
} 