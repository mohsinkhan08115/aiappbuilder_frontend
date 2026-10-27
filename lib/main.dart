import 'package:flutter/material.dart';
import 'app/app.dart';
import 'data/services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefsService = await PreferencesService.create();
  runApp(MyApp(preferencesService: prefsService));
}
