import 'dart:convert';
import 'package:flutter/material.dart';

/// A circular avatar that renders:
///   1. A base64 data-URI image (MemoryImage) — for user-uploaded photos
///   2. A network URL image (foregroundImage) — for DiceBear / Google photos
///   3. An initials fallback — when image is absent or fails to load
///
/// Uses CircleAvatar.foregroundImage so the child (initials) is naturally
/// visible during load and on error — no Image.network + ClipOval nesting
/// needed (which can silently clip or fail in Flutter web CanvasKit mode).
class UserAvatar extends StatefulWidget {
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
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageError = false;

  @override
  void didUpdateWidget(UserAvatar old) {
    super.didUpdateWidget(old);
    if (old.profileImage != widget.profileImage) {
      setState(() => _imageError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme ?? Theme.of(context).colorScheme;
    final initial =
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    // ── Initials widget (used as child / fallback) ──────────────────────────
    final initialsChild = Text(
      initial,
      style: TextStyle(
        fontSize: widget.radius * 0.65,
        fontWeight: FontWeight.w700,
        color: cs.primary,
      ),
    );

    // ── No image or already errored → pure initials ─────────────────────────
    if (widget.profileImage == null ||
        widget.profileImage!.isEmpty ||
        _imageError) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: cs.primary.withOpacity(0.2),
        child: initialsChild,
      );
    }

    // ── Base64 data-URI (user uploaded) ─────────────────────────────────────
    if (widget.profileImage!.startsWith('data:')) {
      try {
        final bytes = base64Decode(widget.profileImage!.split(',').last);
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: cs.primary.withOpacity(0.2),
          child: initialsChild,
        );
      }
    }

    // ── Network URL (DiceBear PNG, Google photo, etc.) ───────────────────────
    // Convert any stray /svg path to /png just in case
    final imgUrl = widget.profileImage!.contains('/svg')
        ? widget.profileImage!.replaceAll('/svg', '/png')
        : widget.profileImage!;

    // foregroundImage renders OVER the child (initials).
    // • While loading  → child (initials) is visible
    // • On success     → image covers the initials
    // • On error       → onForegroundImageError fires; we setState(_imageError)
    //                    so next frame drops back to the pure-initials branch
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: cs.primary.withOpacity(0.15),
      foregroundImage: NetworkImage(imgUrl),
      onForegroundImageError: (_, __) {
        if (mounted) setState(() => _imageError = true);
      },
      child: initialsChild,
    );
  }
}
