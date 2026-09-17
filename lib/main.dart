import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalStore.init();
  runApp(const VibeApp());
}

class LocalStore {
  static const _favoriteBox = 'favorites';
  static const _historyBox = 'history';
  static const _playCountBox = 'play_counts';
  static const _positionBox = 'song_positions';
  static const _playlistBox = 'playlists';
  static const _settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.openBox<String>(_favoriteBox);
    await Hive.openBox<String>(_historyBox);
    await Hive.openBox<int>(_playCountBox);
    await Hive.openBox<int>(_positionBox);
    await Hive.openBox<Map>(_playlistBox);
    await Hive.openBox<dynamic>(_settingsBox);
  }

  static Box<String> favorites() => Hive.box<String>(_favoriteBox);
  static Box<String> history() => Hive.box<String>(_historyBox);
  static Box<int> playCounts() => Hive.box<int>(_playCountBox);
  static Box<int> positions() => Hive.box<int>(_positionBox);
  static Box<Map> playlists() => Hive.box<Map>(_playlistBox);
  static Box<dynamic> settings() => Hive.box<dynamic>(_settingsBox);

  static bool isFavorite(String id) => favorites().containsKey(id);
  static Future<void> setFavorite(String id, bool value) async {
    if (value) {
      await favorites().put(id, id);
    } else {
      await favorites().delete(id);
    }
  }

  static Future<void> savePlayCount(String id, int count) async {
    await playCounts().put(id, count);
  }

  static int getPlayCount(String id) => playCounts().get(id) ?? 0;

  static Future<void> savePosition(String id, int ms) async {
    await positions().put(id, ms);
  }

  static int getPosition(String id) => positions().get(id) ?? 0;

  static Future<void> addHistory(String id) async {
    final box = history();
    final ids = box.values.toList();
    final filtered = ids.where((item) => item != id).toList();
    filtered.add(id);
    await box.clear();
    for (final item in filtered) {
      await box.add(item);
    }
  }

  static List<String> getHistory() => history().values.toList();

  static Future<void> savePlaylist(Playlist playlist) async {
    final box = playlists();
    await box.put(playlist.id, {
      'id': playlist.id,
      'name': playlist.name,
      'songIds': playlist.songIds,
    });
  }

  static Future<void> deletePlaylist(String id) async {
    await playlists().delete(id);
  }

  static List<Playlist> loadPlaylists() {
    return playlists().values.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      return Playlist(
        id: map['id'] as String,
        name: map['name'] as String,
        songIds: List<String>.from(map['songIds'] ?? const []),
      );
    }).toList();
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    await settings().put(key, value);
  }

  static T getSetting<T>(String key, T defaultValue) {
    return settings().get(key, defaultValue: defaultValue) ?? defaultValue;
  }
}

class VibeApp extends StatelessWidget {
  const VibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MusicController()..init(),
      child: MaterialApp(
        title: 'Vibe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C4DFF),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF6F5F8),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C4DFF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}

class MusicController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Song> _songs = [];
  List<Song> _favorites = [];
  List<String> _history = [];
  List<Playlist> _playlists = [];
  List<Song> _queue = [];

  Song? currentSong;
  bool isPlaying = false;
  bool shuffle = false;
  RepeatMode repeatMode = RepeatMode.none;
  String searchText = '';
  int sleepMinutes = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Timer? sleepTimer;
  String lyricsText = 'No local lyrics found';

  final moods = ['Chill', 'Workout', 'Focus', 'Party', 'Sleep'];

  List<Song> get songs => _songs;
  List<Song> get favorites => _favorites;
  List<String> get history => _history;
  List<Playlist> get playlists => _playlists;
  List<Song> get queue => _queue;

  Future<void> init() async {
    final permission = await Permission.storage.request();
    if (permission.isGranted || permission.isLimited) {
      await loadSongs();
    }

    _history = LocalStore.getHistory();
    _playlists = LocalStore.loadPlaylists();
    _favorites = _songs.where((song) => LocalStore.isFavorite(song.id)).toList();

    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        if (repeatMode == RepeatMode.one) {
          seek(Duration.zero);
          _player.play();
        } else {
          _moveToNext();
        }
      }
    });

    _player.positionStream.listen((pos) {
      position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  Future<void> loadSongs() async {
    final items = await _audioQuery.querySongs();
    _songs = items
        .where((song) => song.data.isNotEmpty)
        .map((song) => Song(
              id: song.id.toString(),
              title: song.title,
              artist: song.artist ?? 'Unknown Artist',
              album: song.album ?? 'Unknown Album',
              path: song.data,
              durationMs: song.duration ?? 0,
              favorite: LocalStore.isFavorite(song.id.toString()),
              resumeMs: LocalStore.getPosition(song.id.toString()),
              playCount: LocalStore.getPlayCount(song.id.toString()),
            ))
        .toList();

    _queue = List.from(_songs);
    _favorites = _songs.where((song) => song.favorite).toList();
    notifyListeners();
  }

  List<Song> get filteredSongs {
    if (searchText.trim().isEmpty) {
      return _songs;
    }
    final query = searchText.toLowerCase();
    return _songs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query) ||
          song.path.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> playSong(Song song) async {
    currentSong = song;
    final file = File(song.path);
    if (!file.existsSync()) {
      return;
    }

    await _player.setFilePath(song.path);
    await _player.seek(Duration(milliseconds: song.resumeMs));
    await _player.play();
    isPlaying = true;

    final playCount = LocalStore.getPlayCount(song.id) + 1;
    await LocalStore.savePlayCount(song.id, playCount);
    await LocalStore.addHistory(song.id);
    _history = LocalStore.getHistory();

    final lyrics = await LyricsReader.readForSong(song);
    lyricsText = lyrics ?? 'No local lyrics found';
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (currentSong == null && _songs.isNotEmpty) {
      await playSong(_songs.first);
      return;
    }
    if (isPlaying) {
      await _player.pause();
      isPlaying = false;
    } else {
      await _player.play();
      isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> nextSong() async {
    await _moveToNext();
  }

  Future<void> previousSong() async {
    final list = filteredSongs;
    if (list.isEmpty || currentSong == null) return;
    final currentIndex = list.indexWhere((song) => song.id == currentSong!.id);
    final newIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    await playSong(list[newIndex]);
  }

  Future<void> _moveToNext() async {
    final list = filteredSongs;
    if (list.isEmpty) return;
    if (currentSong == null) {
      await playSong(list.first);
      return;
    }

    if (shuffle) {
      final next = list[(math.Random().nextInt(list.length))];
      await playSong(next);
      return;
    }

    final currentIndex = list.indexWhere((song) => song.id == currentSong!.id);
    final nextIndex = currentIndex >= list.length - 1 ? 0 : currentIndex + 1;
    await playSong(list[nextIndex]);
  }

  Future<void> seek(Duration newPosition) async {
    await _player.seek(newPosition);
    position = newPosition;
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) async {
    final newValue = !song.favorite;
    await LocalStore.setFavorite(song.id, newValue);
    for (var i = 0; i < _songs.length; i++) {
      if (_songs[i].id == song.id) {
        _songs[i] = _songs[i].copyWith(favorite: newValue);
      }
    }
    _favorites = _songs.where((item) => item.favorite).toList();
    notifyListeners();
  }

  void setSearch(String value) {
    searchText = value;
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songIds: const [],
    );
    _playlists = [..._playlists, playlist];
    await LocalStore.savePlaylist(playlist);
    notifyListeners();
  }

  Future<void> addSongToPlaylist(Playlist playlist, Song song) async {
    final updated = playlist.copyWith(
      songIds: [...playlist.songIds, song.id],
    );
    _playlists = _playlists.map((item) {
      return item.id == playlist.id ? updated : item;
    }).toList();
    await LocalStore.savePlaylist(updated);
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists = _playlists.where((item) => item.id != id).toList();
    await LocalStore.deletePlaylist(id);
    notifyListeners();
  }

  Future<void> setSleepTimer(int minutes) async {
    sleepMinutes = minutes;
    sleepTimer?.cancel();
    if (minutes <= 0) {
      notifyListeners();
      return;
    }
    sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      isPlaying = false;
      sleepMinutes = 0;
      notifyListeners();
    });
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void setRepeatMode(RepeatMode mode) {
    repeatMode = mode;
    notifyListeners();
  }

  List<Song> vibeMix() {
    final combined = List<Song>.from(_songs)
      ..sort((a, b) {
        final scoreA = a.playCount + (a.favorite ? 50 : 0);
        final scoreB = b.playCount + (b.favorite ? 50 : 0);
        return scoreB.compareTo(scoreA);
      });
    return combined.take(10).toList();
  }

  List<Song> moodMix(String mood) {
    final query = mood.toLowerCase();
    return _songs.where((song) {
      final text = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
      switch (query) {
        case 'chill':
          return text.contains('chill') || text.contains('acoustic') || text.contains('ambient') || text.contains('lofi');
        case 'workout':
          return text.contains('workout') || text.contains('energy') || text.contains('run');
        case 'focus':
          return text.contains('focus') || text.contains('study') || text.contains('instrumental');
        case 'party':
          return text.contains('party') || text.contains('dance') || text.contains('club');
        case 'sleep':
          return text.contains('sleep') || text.contains('relax') || text.contains('dream');
        default:
          return true;
      }
    }).take(5).toList();
  }

  void saveCurrentPosition() {
    if (currentSong != null) {
      LocalStore.savePosition(currentSong!.id, position.inMilliseconds);
    }
  }

  @override
  void dispose() {
    sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

enum RepeatMode { none, all, one }

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final int durationMs;
  final bool favorite;
  final int resumeMs;
  final int playCount;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.durationMs,
    this.favorite = false,
    this.resumeMs = 0,
    this.playCount = 0,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    int? durationMs,
    bool? favorite,
    int? resumeMs,
    int? playCount,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      durationMs: durationMs ?? this.durationMs,
      favorite: favorite ?? this.favorite,
      resumeMs: resumeMs ?? this.resumeMs,
      playCount: playCount ?? this.playCount,
    );
  }
}

class Playlist {
  final String id;
  final String name;
  final List<String> songIds;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
  });

  Playlist copyWith({String? id, String? name, List<String>? songIds}) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? List<String>.from(this.songIds),
    );
  }
}

class LyricsReader {
  static Future<String?> readForSong(Song song) async {
    final file = File(song.path);
    final directory = file.parent;
    try {
      final files = directory.listSync();
      for (final entry in files) {
        if (entry is File && entry.path.toLowerCase().endsWith('.lrc')) {
          return await entry.readAsString();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeTab(),
      const LibraryTab(),
      const PlaylistTab(),
      const FavoritesTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.playlist_play_outlined), selectedIcon: Icon(Icons.playlist_play_rounded), label: 'Playlists'),
              NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Favorites'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final mix = controller.vibeMix();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('For your ears', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: controller.moods.map((mood) {
              return FilledButton.tonal(
                onPressed: () {
                  final list = controller.moodMix(mood);
                  if (list.isNotEmpty) {
                    controller.playSong(list.first);
                  }
                },
                child: Text(mood),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Vibe Mix', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mix.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final song = mix[index];
                return SizedBox(
                  width: 150,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => controller.playSong(song),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AlbumArt(path: song.path, size: 116),
                            const SizedBox(height: 8),
                            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recently played', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (controller.history.isEmpty)
            const Text('No songs played yet')
          else
            ...controller.history.take(5).map((id) {
              final song = controller.songs.firstWhere(
                (item) => item.id == id,
                orElse: () => controller.songs.first,
              );
              return ListTile(
                leading: AlbumArt(path: song.path, size: 46),
                title: Text(song.title),
                subtitle: Text(song.artist),
                onTap: () => controller.playSong(song),
              );
            }),
        ],
      ),
    );
  }
}

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final songs = controller.filteredSongs;

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: controller.setSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search songs, albums, artists',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: songs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: AlbumArt(path: song.path, size: 52),
                  title: Text(song.title),
                  subtitle: Text('${song.artist} • ${song.album}'),
                  trailing: IconButton(
                    onPressed: () => controller.toggleFavorite(song),
                    icon: Icon(
                      song.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: song.favorite ? Colors.pink : null,
                    ),
                  ),
                  onTap: () => controller.playSong(song),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistTab extends StatelessWidget {
  const PlaylistTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _showCreateDialog(context);
          if (name != null && name.trim().isNotEmpty) {
            controller.createPlaylist(name.trim());
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Playlist'),
      ),
      body: controller.playlists.isEmpty
          ? const Center(child: Text('No playlists yet'))
          : ListView.builder(
              itemCount: controller.playlists.length,
              itemBuilder: (context, index) {
                final playlist = controller.playlists[index];
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songIds.length} songs'),
                  trailing: IconButton(
                    onPressed: () => controller.deletePlaylist(playlist.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                );
              },
            ),
    );
  }

  Future<String?> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
  }
}

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final songs = controller.favorites;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: songs.isEmpty
          ? const Center(child: Text('Tap the heart on a track to save it'))
          : ListView.separated(
              itemCount: songs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: AlbumArt(path: song.path, size: 50),
                  title: Text(song.title),
                  subtitle: Text(song.artist),
                  trailing: IconButton(
                    onPressed: () => controller.toggleFavorite(song),
                    icon: const Icon(Icons.favorite_rounded, color: Colors.pink),
                  ),
                  onTap: () => controller.playSong(song),
                );
              },
            ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: const Text('Sleep Timer'),
            subtitle: Text(controller.sleepMinutes == 0 ? 'Off' : '${controller.sleepMinutes} min'),
            onTap: () => _showSleepDialog(context, controller),
          ),
          SwitchListTile(
            value: controller.shuffle,
            onChanged: (_) => controller.toggleShuffle(),
            title: const Text('Shuffle'),
            secondary: const Icon(Icons.shuffle_rounded),
          ),
          ListTile(
            title: const Text('Repeat Mode'),
            subtitle: Text(controller.repeatMode.name),
            onTap: () {
              switch (controller.repeatMode) {
                case RepeatMode.none:
                  controller.setRepeatMode(RepeatMode.all);
                  break;
                case RepeatMode.all:
                  controller.setRepeatMode(RepeatMode.one);
                  break;
                case RepeatMode.one:
                  controller.setRepeatMode(RepeatMode.none);
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSleepDialog(BuildContext context, MusicController controller) {
    final options = [10, 20, 30, 45, 60];
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Sleep timer'),
        children: [
          ...options.map((minutes) => SimpleDialogOption(
                onPressed: () {
                  controller.setSleepTimer(minutes);
                  Navigator.pop(context);
                },
                child: Text('$minutes minutes'),
              )),
          SimpleDialogOption(
            onPressed: () {
              controller.setSleepTimer(0);
              Navigator.pop(context);
            },
            child: const Text('Off'),
          ),
        ],
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final song = controller.currentSong;
    if (song == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListTile(
        leading: AlbumArt(path: song.path, size: 48),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => controller.togglePlayPause(),
              icon: Icon(controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NowPlayingPage()),
              ),
              icon: const Icon(Icons.open_in_full_rounded),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingPage()),
        ),
      ),
    );
  }
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final song = controller.currentSong;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('No song selected')));
    }

    final totalMs = song.durationMs == 0 ? 1 : song.durationMs;
    final sliderValue = controller.position.inMilliseconds.clamp(0, totalMs).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              AlbumArt(path: song.path, size: 280),
              const SizedBox(height: 24),
              Text(song.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(song.artist, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 18),
              Slider(
                value: sliderValue,
                min: 0,
                max: totalMs.toDouble(),
                onChanged: (value) => controller.seek(Duration(milliseconds: value.toInt())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(controller.position)),
                    Text(formatDuration(Duration(milliseconds: totalMs))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(onPressed: () => controller.previousSong(), icon: const Icon(Icons.skip_previous_rounded, size: 36)),
                  IconButton(onPressed: () => controller.togglePlayPause(), icon: Icon(controller.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 62)),
                  IconButton(onPressed: () => controller.nextSong(), icon: const Icon(Icons.skip_next_rounded, size: 36)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToggleButton(icon: Icons.shuffle_rounded, active: controller.shuffle, onTap: controller.toggleShuffle),
                  _ToggleButton(
                    icon: Icons.repeat_rounded,
                    active: controller.repeatMode != RepeatMode.none,
                    onTap: () {
                      switch (controller.repeatMode) {
                        case RepeatMode.none:
                          controller.setRepeatMode(RepeatMode.all);
                          break;
                        case RepeatMode.all:
                          controller.setRepeatMode(RepeatMode.one);
                          break;
                        case RepeatMode.one:
                          controller.setRepeatMode(RepeatMode.none);
                          break;
                      }
                    },
                  ),
                  _ToggleButton(icon: Icons.favorite_rounded, active: song.favorite, onTap: () => controller.toggleFavorite(song)),
                  _ToggleButton(icon: Icons.queue_music_rounded, active: false, onTap: () {}),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  controller.lyricsText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest;
    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

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
                errorBuilder: (_, __, ___) => const _FallbackIcon(),
              ),
            )
          : const _FallbackIcon(),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.music_note_rounded, size: 38, color: Colors.white),
    );
  }
}
