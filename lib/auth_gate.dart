import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import 'login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/household_onboarding_screen.dart';
import 'services/household_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authStream = FirebaseAuth.instance.authStateChanges();
  final _householdService = HouseholdService();

  bool bypassAuth = false;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Widget _loadingScreen() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _messageScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('HouseHeld'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _householdGate(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(user.uid),
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasError) {
          return _messageScreen(
            'Unable to load your profile. '
            'Please sign out and try again.',
          );
        }

        if (!profileSnapshot.hasData) {
          return _loadingScreen();
        }

        final profile = profileSnapshot.data!.data();

        // Signup may create the Auth account before saving its profile
        // This listener will update when the profile becomes available
        if (profile == null) {
          return _messageScreen(
            'Waiting for your profile to finish setting up. '
            'If this message remains, your profile may not have '
            'been saved successfully.',
          );
        }

        final householdID = profile['householdID'];

        // No household yet; show the create/join screen
        if (householdID == null || householdID == '') {
          return HouseholdOnboardingScreen(
            key: ValueKey('onboarding-${user.uid}'),
            onCreate: (name) async {
              await _householdService.createHousehold(name);
            },
            onJoin: (id) async {
              await _householdService.joinHousehold(id);
            },
            onLogout: _signOut,
          );
        }

        if (householdID is! String) {
          return _messageScreen(
            'Your profile has an invalid household ID. '
            'Please contact your team to correct it.',
          );
        }

        // Confirm the membership exists before showing the home screen
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('${user.uid}-$householdID'),
          stream: FirebaseFirestore.instance
            .collection('households')
            .doc(householdID)
            .collection('members')
            .doc(user.uid)
            .snapshots(),
          builder: (context, memberSnapshot) {
            if (memberSnapshot.hasError) {
              return _messageScreen(
                'Unable to load your household membership. '
                'Please sign out and try again.',
              );
            }

            if (!memberSnapshot.hasData) {
              return _loadingScreen();
            }

            final member = memberSnapshot.data!.data();

            if (member == null || 
                member['userID'] != user.uid ||
                member['householdID'] != householdID) {
              return _messageScreen(
                'Your profile and household membership do not match. '
                'Please contact your team to correct it.',
              );
          }

            return HomeScreen(
              title: 'HouseHeld',
              onLogout: _signOut,
            );
          },
        );
      },
    );
  }          

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && bypassAuth) {
      return HomeScreen(
        title: 'HouseHeld',
        onLogout: () {
          setState(() {
            bypassAuth = false;
          });
        },
      );
    }

    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageScreen(
            'Unable to check your sign-in status. Please restart the app.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        final user = snapshot.data;

        if (user != null) {
          return _householdGate(user);
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
