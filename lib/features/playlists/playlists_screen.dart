import 'package:flutter/material.dart';
import '../../core/strings.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          AppStrings.navPlaylists,
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
