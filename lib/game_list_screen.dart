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
          ListTile(
            title: const Text('Icy Tower'),
            onTap: () {
              Navigator.pushNamed(context, '/icy_tower_game');
            },
          ),
          ListTile(
            title: const Text('Cave Lander'),
            onTap: () {
              Navigator.pushNamed(context, '/cave_lander_game');
            },
          ),
          ListTile(
            title: const Text('Wall Kickers'),
            onTap: () {
              Navigator.pushNamed(context, '/wall_kickers_game');
            },
          ),
          ListTile(
            title: const Text('Ball Runner'),
            onTap: () {
              Navigator.pushNamed(context, '/ball_runner_game');
            },
          ),
          ListTile(
            title: const Text('Swipe Tiles'),
            onTap: () {
              Navigator.pushNamed(context, '/swipe_tiles_game');
            },
          ),
          ListTile(
            title: const Text('Memory Match'),
            onTap: () {
              Navigator.pushNamed(context, '/memory_match_game');
            },
          ),
          ListTile(
            title: const Text('Number Rush'),
            onTap: () {
              Navigator.pushNamed(context, '/number_rush_game');
            },
          ),
          ListTile(
            title: const Text('Sudoku Game'),
            onTap: () {
              Navigator.pushNamed(context, '/sudoku_game');
            },
          ),
          ListTile(
            title: const Text('Block Drop Game'),
            onTap: () {
              Navigator.pushNamed(context, '/block_drop_game');
            },
          ),
        ],
      ),
    );
  }
}
