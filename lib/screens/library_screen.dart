import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_controller.dart';
import '../widgets/album_art.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final songs = controller.filteredSongs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: controller.setSearch,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search songs, artists, albums',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                  leading: AlbumArt(path: song.path, size: 54),
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
