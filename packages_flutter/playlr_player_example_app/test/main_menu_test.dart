import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/screen/main_menu_screen.dart';

void main() {
  testWidgets('main menu items', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Play one short song (5s)'), findsOneWidget);
    expect(find.text('Queue clips of 2 songs'), findsOneWidget);
    expect(find.text(defaultAppAudioPlayerImplementation.name), findsOneWidget);
  });
}
