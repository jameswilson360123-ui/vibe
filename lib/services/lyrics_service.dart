import 'dart:io';

import '../models/song.dart';

class LyricsService {
  static Future<String?> loadLyricsForSong(Song song) async {
    final file = File(song.path);
    final directory = file.parent;
    final candidates = <File>[];

    try {
      final entries = directory.listSync();
      for (final entry in entries) {
        if (entry is File && entry.path.toLowerCase().endsWith('.lrc')) {
          candidates.add(entry);
        }
      }
    } catch (_) {
      return null;
    }

    if (candidates.isEmpty) {
      return null;
    }

    try {
      return await candidates.first.readAsString();
    } catch (_) {
      return null;
    }
  }
}
