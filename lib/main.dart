import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const HouseHeld());
}

class HouseHeld extends StatelessWidget {
  const HouseHeld({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HouseHeld',
      debugShowCheckedModeBanner: false,
      theme: buildHouseheldTheme(),
      home: const AuthGate(),
    );
  }
}
