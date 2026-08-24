import 'package:flutter/widgets.dart';
import 'package:playlr_player_example_app/src/app.dart';
import 'package:playlr_player_example_app/src/app_context.dart';

/// Simple player example app entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAppContext();
  runApp(const PlaylrPlayerExampleApp());
}
