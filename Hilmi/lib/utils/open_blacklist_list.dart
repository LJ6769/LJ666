import 'package:flutter/material.dart';
import 'package:hilmi/screens/blacklist_list_screen.dart';

Future<void> openBlacklistListScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => const BlacklistListScreen(),
    ),
  );
}
