import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool bypassAuth = false;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && bypassAuth) {
      return MyHomePage(
        title: 'HouseHeld',
        onLogout: () {
          setState(() {
            bypassAuth = false;
          });
        },
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return MyHomePage(
            title: 'HouseHeld',
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
            },
          );
        }

        return LoginScreen(
          onBypass: kDebugMode
              ? () {
                  setState(() {
                    bypassAuth = true;
                  });
                }
              : null,
        );
      },
    );
  }
}
