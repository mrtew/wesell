import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';

class SearchBarWidget extends ConsumerWidget {
  final TextEditingController? controller;
  final bool showCameraIcon;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onTap;
  final VoidCallback? onSearch;
  final bool readOnly;
  final bool autofocus;
  final Function(String)? onSubmitted;

  const SearchBarWidget({
    Key? key,
    this.controller,
    this.showCameraIcon = false,
    this.onCameraPressed,
    this.onTap,
    this.onSearch,
    this.readOnly = false,
    this.autofocus = false,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      autofocus: autofocus,
      onTap: onTap,
      onSubmitted: (value) {
        if (onSubmitted != null) {
          onSubmitted!(value);
        }
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search items...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: showCameraIcon 
            ? IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: onCameraPressed,
              )
            : onSearch != null 
              ? IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: onSearch,
                )
              : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
} 