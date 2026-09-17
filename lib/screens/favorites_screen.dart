import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_controller.dart';
import '../widgets/album_art.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final songs = controller.favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: songs.isEmpty
          ? const Center(child: Text('Tap the heart on any song to save it'))
          : ListView.separated(
              itemCount: songs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: AlbumArt(path: song.path, size: 52),
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
