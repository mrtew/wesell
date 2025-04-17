import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData? icon;

  Category({
    required this.id,
    required this.name,
    this.icon,
  });
}

// Predefined categories for the app
final List<Category> categories = [
  Category(
    id: '',
    name: '',
    // icon: Icons.devices,
  ),
  Category(
    id: 'electronics',
    name: 'Electronics',
    icon: Icons.devices,
  ),
  Category(
    id: 'clothing',
    name: 'Clothing',
    icon: Icons.shopping_bag,
  ),
  Category(
    id: 'home',
    name: 'Home & Garden',
    icon: Icons.home,
  ),
  Category(
    id: 'books',
    name: 'Books & Media',
    icon: Icons.menu_book,
  ),
  Category(
    id: 'sports',
    name: 'Sports & Outdoor',
    icon: Icons.sports_basketball,
  ),
  Category(
    id: 'toys',
    name: 'Toys & Games',
    icon: Icons.toys,
  ),
  Category(
    id: 'beauty',
    name: 'Beauty & Health',
    icon: Icons.spa,
  ),
  Category(
    id: 'automotive',
    name: 'Automotive',
    icon: Icons.directions_car,
  ),
  Category(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz,
  ),
]; 