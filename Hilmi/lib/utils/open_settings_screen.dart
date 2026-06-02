import 'package:flutter/material.dart';
import 'package:hilmi/screens/settings_screen.dart';

Future<void> openSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => const SettingsScreen(),
    ),
  );
}
