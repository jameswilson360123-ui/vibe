import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_controller.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _showCreateDialog(context);
          if (name != null && name.trim().isNotEmpty) {
            controller.createPlaylist(name.trim());
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New playlist'),
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
                    onPressed: () => controller.removePlaylist(playlist.id),
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
      builder: (context) => AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
