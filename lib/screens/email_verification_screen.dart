import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Email verification screen appears only for new
// accounts whose emails have not been verified yet.

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Check if an already-verified user returns to the app:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkVerification(showUnverifiedMessage: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerification(showUnverifiedMessage: false);
    }
  }

  // Error handler:
  String _errorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Too many requests. Please try again later';

      case 'network-request-failed':
        return 'Unable to connect. Check your internet connection and try again.';

      case 'user-disabled':
        return 'This account has been disabled...';

      default:
        return error.message ?? 'Something went wrong, please try again.';
    }
  }

  // Method to check verification status:
  Future<void> _checkVerification({bool showUnverifiedMessage = true}) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) return;

      if (refreshedUser.emailVerified) {
        await refreshedUser.getIdToken(true);
        return;
      }

      if (mounted && showUnverifiedMessage) {
        setState(() {
          _message =
              'Your email is not verified yet. '
              'Please use the link sent to your '
              'email\'s inbox and try again.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = _errorMessage(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to check verification status. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // Method to resend the verification email:
  Future<void> _resendEmail() async {
    if (_busy) return;

    // Use time to prevent too many requests:
    final now = DateTime.now();

    if (_lastSentAt != null && now.difference(_lastSentAt!).inSeconds < 60) {
      setState(() {
        _message = 'Please wait at least 60 seconds between requests.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError('Please sign in first.');
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw StateError('Please sign in first.');
      }

      if (refreshedUser.emailVerified) {
        await refreshedUser.getIdToken(true);
        return;
      }

      await refreshedUser.sendEmailVerification();

      _lastSentAt = DateTime.now();

      if (mounted) {
        setState(() {
          _message =
              'Verification email sent! '
              'Please check your inbox and spam folder.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = _errorMessage(error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to send verification email. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // Method to sign out the user:
  Future<void> _signOut() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to sign out. Please try again.';
          _busy = false;
        });
      }
    }
  }

  // Actual verification screen UI:
  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'your email address';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 76,
                    color: AppColors.forest,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'To use HouseHeld, please verify your '
                    'registered email address first.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.forest,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Click on the link sent to your email, '
                    'then tap "I\'ve Verified My Email".',
                    textAlign: TextAlign.center,
                  ),

                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    Text(_message!, textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 28),

                  if (_busy)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _checkVerification,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text("I've Verified My Email"),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resendEmail,
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Resend Verification Email'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
