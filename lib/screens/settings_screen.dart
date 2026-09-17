import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/music_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MusicController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: const Text('Sleep timer'),
            subtitle: Text(controller.sleepMinutes == 0 ? 'Off' : '${controller.sleepMinutes} minutes'),
            onTap: () => _showSleepDialog(context, controller),
          ),
          SwitchListTile(
            value: controller.shuffle,
            onChanged: (value) => controller.setShuffle(value),
            title: const Text('Shuffle'),
            secondary: const Icon(Icons.shuffle_rounded),
          ),
          ListTile(
            title: const Text('Repeat mode'),
            subtitle: Text(controller.repeatMode.name),
            onTap: () {
              final next = controller.repeatMode == RepeatMode.none
                  ? RepeatMode.all
                  : controller.repeatMode == RepeatMode.all
                      ? RepeatMode.one
                      : RepeatMode.none;
              controller.setRepeatMode(next);
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
      builder: (context) => SimpleDialog(
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
