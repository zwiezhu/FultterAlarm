import 'package:flutter/material.dart';

class GameListScreen extends StatelessWidget {
  const GameListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casual Play'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Piano Tiles'),
            onTap: () {
              Navigator.pushNamed(context, '/game');
            },
          ),
          ListTile(
            title: const Text('Sky Tower'),
            onTap: () {
              Navigator.pushNamed(context, '/sky_tower_game');
            },
          ),
          ListTile(
            title: const Text('Wall Bounce'),
            onTap: () {
              Navigator.pushNamed(context, '/wall_bounce_game');
            },
          ),
        ],
      ),
    );
  }
}
