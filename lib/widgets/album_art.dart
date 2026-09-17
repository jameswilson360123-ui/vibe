import 'dart:io';

import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.path,
    required this.size,
  });

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: file.existsSync()
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackIcon(),
              ),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return const Center(
      child: Icon(Icons.music_note_rounded, size: 38, color: Colors.white),
    );
  }
}
