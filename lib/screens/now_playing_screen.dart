import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_controller.dart';
import '../widgets/album_art.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();
    final song = controller.currentSong;

    if (song == null) {
      return const Scaffold(
        body: Center(child: Text('No song selected')),
      );
    }

    final totalMs = song.durationMs == 0 ? 1 : song.durationMs;
    final currentValue = controller.position.inMilliseconds.clamp(0, totalMs).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              AlbumArt(path: song.path, size: 280),
              const SizedBox(height: 26),
              Text(
                song.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.artist,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              Slider(
                value: currentValue,
                min: 0,
                max: totalMs.toDouble(),
                onChanged: (value) {
                  controller.seek(Duration(milliseconds: value.toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(controller.position)),
                    Text(_formatDuration(Duration(milliseconds: totalMs))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => controller.skipToPrevious(),
                    icon: const Icon(Icons.skip_previous_rounded, size: 34),
                  ),
                  IconButton(
                    onPressed: () => controller.togglePlayPause(),
                    icon: Icon(
                      controller.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 60,
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.skipToNext(),
                    icon: const Icon(Icons.skip_next_rounded, size: 34),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: Icons.shuffle_rounded,
                    active: controller.shuffle,
                    onTap: () => controller.setShuffle(!controller.shuffle),
                  ),
                  _ControlButton(
                    icon: Icons.repeat_rounded,
                    active: controller.repeatMode != RepeatMode.none,
                    onTap: () {
                      final next = controller.repeatMode == RepeatMode.none
                          ? RepeatMode.all
                          : controller.repeatMode == RepeatMode.all
                              ? RepeatMode.one
                              : RepeatMode.none;
                      controller.setRepeatMode(next);
                    },
                  ),
                  _ControlButton(
                    icon: Icons.favorite_rounded,
                    active: song.favorite,
                    onTap: () => controller.toggleFavorite(song),
                  ),
                  _ControlButton(
                    icon: Icons.queue_music_rounded,
                    active: false,
                    onTap: () {},
                  ),
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
                  controller.currentLyrics ?? 'No local lyrics loaded for this track.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
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
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: active ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
