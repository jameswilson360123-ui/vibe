import 'package:hive_flutter/hive_flutter.dart';

class LocalDatabase {
  static const String playlistBoxName = 'playlists';
  static const String favoritesBoxName = 'favorites';
  static const String historyBoxName = 'history';
  static const String playCountBoxName = 'play_count';
  static const String positionBoxName = 'positions';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.openBox<String>(playlistBoxName);
    await Hive.openBox<String>(favoritesBoxName);
    await Hive.openBox<String>(historyBoxName);
    await Hive.openBox<int>(playCountBoxName);
    await Hive.openBox<int>(positionBoxName);
    await Hive.openBox<dynamic>(settingsBoxName);
  }

  static Box<String> playlistsBox() => Hive.box<String>(playlistBoxName);
  static Box<String> favoritesBox() => Hive.box<String>(favoritesBoxName);
  static Box<String> historyBox() => Hive.box<String>(historyBoxName);
  static Box<int> playCountsBox() => Hive.box<int>(playCountBoxName);
  static Box<int> positionsBox() => Hive.box<int>(positionBoxName);
  static Box<dynamic> settingsBox() => Hive.box<dynamic>(settingsBoxName);

  static Future<void> saveSongPosition(String songId, int milliseconds) async {
    await positionsBox().put(songId, milliseconds);
  }

  static int getSongPosition(String songId) => positionsBox().get(songId) ?? 0;

  static Future<void> saveFavorite(String songId, bool value) async {
    if (value) {
      await favoritesBox().put(songId, songId);
    } else {
      await favoritesBox().delete(songId);
    }
  }

  static bool isFavorite(String songId) => favoritesBox().containsKey(songId);

  static Future<void> savePlayCount(String songId, int count) async {
    await playCountsBox().put(songId, count);
  }

  static int getPlayCount(String songId) => playCountsBox().get(songId) ?? 0;

  static Future<void> saveHistory(String songId) async {
    final box = historyBox();
    final current = box.values.toList();
    final filtered = current.where((id) => id != songId).toList();
    filtered.add(songId);
    await box.clear();
    for (final item in filtered) {
      await box.add(item);
    }
  }

  static List<String> getHistory() => historyBox().values.toList();

  static Future<void> saveSetting(String key, dynamic value) async {
    await settingsBox().put(key, value);
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox().get(key, defaultValue: defaultValue);
  }
}
