import 'package:flutter/material.dart';
import 'package:playlr_player_example_app/src/screen/main_menu_screen.dart';

/// Simple player example app.
class PlaylrPlayerExampleApp extends StatelessWidget {
  /// Simple player example app.
  const PlaylrPlayerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playlr player example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}
