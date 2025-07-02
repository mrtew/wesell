import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CachedAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final double width;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  const CachedAvatarWidget({
    super.key,
    this.avatarUrl,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: backgroundColor ?? Colors.grey[200],
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: width,
                  height: height,
                  color: backgroundColor ?? Colors.grey[200],
                  child: Center(
                    child: SizedBox(
                      width: (iconSize ?? 40) * 0.6,
                      height: (iconSize ?? 40) * 0.6,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: width,
                  height: height,
                  color: backgroundColor ?? Colors.grey[200],
                  child: Icon(
                    Icons.person,
                    color: iconColor ?? Colors.grey[400],
                    size: iconSize ?? 40,
                  ),
                ),
              )
            : Icon(
                Icons.person, 
                color: iconColor ?? Colors.grey[400], 
                size: iconSize ?? 40,
              ),
      ),
    );
  }
} 