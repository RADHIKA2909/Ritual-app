import 'dart:convert';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? profileImage;
  final double radius;
  final ColorScheme? colorScheme;

  const UserAvatar({
    super.key,
    required this.name,
    this.profileImage,
    this.radius = 20,
    this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme ?? Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (profileImage != null && profileImage!.isNotEmpty) {
      try {
        if (profileImage!.startsWith('data:')) {
          final bytes = base64Decode(profileImage!.split(',').last);
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
          );
        } else {
          return CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(profileImage!),
          );
        }
      } catch (_) {
        // fall through to initials
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary.withOpacity(0.2),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }
}
