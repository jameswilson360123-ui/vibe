import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_controller.dart';
import '../widgets/album_art.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final vibeMix = controller.vibeMix();
    final moods = ['Chill', 'Workout', 'Focus', 'Party', 'Sleep'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibe'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'For your ears',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: moods.map((mood) {
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
          const Text(
            'Vibe Mix',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vibeMix.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final song = vibeMix[index];
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
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
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
          const Text(
            'Recently played',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (controller.history.isEmpty)
            const Text('No recent tracks yet')
          else
            ...controller.history.take(5).map((id) {
              final song = controller.library.firstWhere(
                (item) => item.id == id,
                orElse: () => controller.library.first,
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
