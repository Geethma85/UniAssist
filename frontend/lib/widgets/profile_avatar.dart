import 'dart:convert';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoBase64,
    this.size = 44,
    this.initials = '',
  });

  final String? photoBase64;
  final double size;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget fallback() {
      return Center(
        child: initials.isEmpty
            ? Icon(
                Icons.person,
                size: size * 0.5,
                color: colors.onPrimaryContainer,
              )
            : Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimaryContainer,
                ),
              ),
      );
    }

    Widget content = fallback();

    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        content = Image.memory(
          base64Decode(photoBase64!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, error, stackTrace) => fallback(),
        );
      } on FormatException {
        content = fallback();
      }
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: colors.primaryContainer,
        child: content,
      ),
    );
  }
}