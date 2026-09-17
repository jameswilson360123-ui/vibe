class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final String? albumArtPath;
  final int durationMs;
  final bool favorite;
  final int resumePositionMs;
  final int playCount;
  final int lastPlayedAt;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    this.albumArtPath,
    required this.durationMs,
    this.favorite = false,
    this.resumePositionMs = 0,
    this.playCount = 0,
    this.lastPlayedAt = 0,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    String? albumArtPath,
    int? durationMs,
    bool? favorite,
    int? resumePositionMs,
    int? playCount,
    int? lastPlayedAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      durationMs: durationMs ?? this.durationMs,
      favorite: favorite ?? this.favorite,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'path': path,
        'albumArtPath': albumArtPath,
        'durationMs': durationMs,
        'favorite': favorite,
        'resumePositionMs': resumePositionMs,
        'playCount': playCount,
        'lastPlayedAt': lastPlayedAt,
      };

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      path: map['path'] as String,
      albumArtPath: map['albumArtPath'] as String?,
      durationMs: map['durationMs'] as int? ?? 0,
      favorite: map['favorite'] as bool? ?? false,
      resumePositionMs: map['resumePositionMs'] as int? ?? 0,
      playCount: map['playCount'] as int? ?? 0,
      lastPlayedAt: map['lastPlayedAt'] as int? ?? 0,
    );
  }
}

class PlaylistModel {
  final String id;
  final String name;
  final List<String> songIds;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.songIds,
  });

  PlaylistModel copyWith({String? id, String? name, List<String>? songIds}) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? List<String>.from(this.songIds),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'songIds': songIds,
      };

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      songIds: List<String>.from(map['songIds'] ?? const []),
    );
  }
}
