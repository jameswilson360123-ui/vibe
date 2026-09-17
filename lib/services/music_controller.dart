import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database/local_database.dart';
import '../models/song.dart';

enum RepeatMode { none, all, one }

class MusicController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<Song> _library = [];
  List<Song> _favorites = [];
  List<String> _history = [];
  List<PlaylistModel> _playlists = [];
  Song? _currentSong;
  bool _isPlaying = false;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.none;
  int _sleepMinutes = 0;
  Timer? _sleepTimer;
  String _searchQuery = '';
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _currentLyrics;

  List<Song> get library => _library;
  List<Song> get favorites => _favorites;
  List<String> get history => _history;
  List<PlaylistModel> get playlists => _playlists;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  int get sleepMinutes => _sleepMinutes;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get currentLyrics => _currentLyrics;

  MusicController() {
    _player.playbackEventStream.listen((event) {
      _position = event.updatePosition;
      _duration = event.duration ?? Duration.zero;
      _isPlaying = event.playing;
      notifyListeners();
    });

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (_repeatMode == RepeatMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
      notifyListeners();
    });
  }

  Future<void> loadLibrary() async {
    _loading = true;
    notifyListeners();

    final status = await Permission.storage.request();
    if (!status.isGranted && !status.isLimited) {
      _loading = false;
      notifyListeners();
      return;
    }

    final response = await _audioQuery.querySongs();
    _library = response
        .where((song) => song.data.isNotEmpty)
        .map((song) => Song(
              id: song.id.toString(),
              title: song.title,
              artist: song.artist ?? 'Unknown Artist',
              album: song.album ?? 'Unknown Album',
              path: song.data,
              durationMs: song.duration ?? 0,
              favorite: LocalDatabase.isFavorite(song.id.toString()),
              resumePositionMs: LocalDatabase.getSongPosition(song.id.toString()),
              playCount: LocalDatabase.getPlayCount(song.id.toString()),
            ))
        .toList();

    _favorites = _library.where((song) => song.favorite).toList();
    _history = LocalDatabase.getHistory();
    _loading = false;
    notifyListeners();
  }

  List<Song> filteredSongs() {
    final source = _searchQuery.isEmpty
        ? _library
        : _library.where((song) {
            final query = _searchQuery.toLowerCase();
            return song.title.toLowerCase().contains(query) ||
                song.artist.toLowerCase().contains(query) ||
                song.album.toLowerCase().contains(query) ||
                song.path.toLowerCase().contains(query);
          }).toList();
    return source;
  }

  void setSearch(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    final file = File(song.path);
    if (!file.existsSync()) {
      return;
    }

    _currentSong = song;
    final resume = Duration(milliseconds: song.resumePositionMs);
    await _player.setFilePath(song.path);
    await _player.seek(resume);
    await _player.play();
    _isPlaying = true;

    final count = LocalDatabase.getPlayCount(song.id) + 1;
    await LocalDatabase.savePlayCount(song.id, count);
    await LocalDatabase.saveHistory(song.id);
    _history = LocalDatabase.getHistory();

    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) async {
    final value = !song.favorite;
    await LocalDatabase.saveFavorite(song.id, value);
    _library = _library.map((item) {
      if (item.id == song.id) {
        return item.copyWith(favorite: value);
      }
      return item;
    }).toList();
    _favorites = _library.where((item) => item.favorite).toList();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null && _library.isNotEmpty) {
      await playSong(_library.first);
      return;
    }

    if (_isPlaying) {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
      return;
    }

    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> skipToNext() async {
    final songs = filteredSongs();
    if (songs.isEmpty) return;

    if (_currentSong == null) {
      await playSong(songs.first);
      return;
    }

    final currentIndex = songs.indexWhere((song) => song.id == _currentSong!.id);
    final nextIndex = currentIndex == -1 ? 0 : (currentIndex + 1) % songs.length;
    await playSong(songs[nextIndex]);
  }

  Future<void> skipToPrevious() async {
    final songs = filteredSongs();
    if (songs.isEmpty) return;

    if (_currentSong == null) {
      await playSong(songs.first);
      return;
    }

    final currentIndex = songs.indexWhere((song) => song.id == _currentSong!.id);
    final prevIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    await playSong(songs[prevIndex]);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }

  Future<void> setShuffle(bool value) async {
    _shuffle = value;
    notifyListeners();
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeatMode = mode;
    notifyListeners();
  }

  Future<void> setSleepTimer(int minutes) async {
    _sleepMinutes = minutes;
    _sleepTimer?.cancel();

    if (minutes <= 0) {
      notifyListeners();
      return;
    }

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _player.pause();
      _isPlaying = false;
      _sleepMinutes = 0;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> saveSongPosition(String songId, int milliseconds) async {
    await LocalDatabase.saveSongPosition(songId, milliseconds);
    final index = _library.indexWhere((song) => song.id == songId);
    if (index != -1) {
      _library[index] = _library[index].copyWith(resumePositionMs: milliseconds);
    }
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final playlist = PlaylistModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songIds: const [],
    );
    _playlists = [..._playlists, playlist];
    notifyListeners();
  }

  void addSongToPlaylist(PlaylistModel playlist, Song song) {
    final updated = playlist.copyWith(
      songIds: [...playlist.songIds, song.id],
    );
    _playlists = _playlists
        .map((item) => item.id == playlist.id ? updated : item)
        .toList();
    notifyListeners();
  }

  void removeSongFromPlaylist(PlaylistModel playlist, String songId) {
    final updated = playlist.copyWith(
      songIds: playlist.songIds.where((id) => id != songId).toList(),
    );
    _playlists = _playlists
        .map((item) => item.id == playlist.id ? updated : item)
        .toList();
    notifyListeners();
  }

  void removePlaylist(String id) {
    _playlists = _playlists.where((item) => item.id != id).toList();
    notifyListeners();
  }

  List<Song> vibeMix() {
    final songs = List<Song>.from(_library)
      ..sort((a, b) {
        final scoreA = a.playCount + (a.favorite ? 100 : 0);
        final scoreB = b.playCount + (b.favorite ? 100 : 0);
        return scoreB.compareTo(scoreA);
      });
    return songs.take(10).toList();
  }

  List<Song> moodMix(String mood) {
    final candidates = _library.where((song) {
      final query = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
      switch (mood) {
        case 'Chill':
          return query.contains('chill') || query.contains('lofi') || query.contains('acoustic');
        case 'Workout':
          return query.contains('workout') || query.contains('energy') || query.contains('run');
        case 'Focus':
          return query.contains('focus') || query.contains('study') || query.contains('instrumental');
        case 'Party':
          return query.contains('party') || query.contains('dance') || query.contains('club');
        case 'Sleep':
          return query.contains('sleep') || query.contains('ambient') || query.contains('relax');
        default:
          return true;
      }
    }).toList();

    return candidates.length > 5 ? candidates.take(5).toList() : candidates;
  }

  Future<void> disposePlayer() async {
    _sleepTimer?.cancel();
    await _player.dispose();
  }

  @override
  void dispose() {
    disposePlayer();
    super.dispose();
  }
}
