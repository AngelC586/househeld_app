import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? errorMessage;
  bool isLoading = false;
  bool obscurePassword = true;

  // Sign in existing user:
  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Both Email and Password are required.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = _getLoginErrorMessage(e);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Login error messages:
  String _getLoginErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'The Email or Password you entered is incorrect.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many sign-in attempts. Please try again later.';

      case 'network-request-failed':
        return 'Unable to connect. Check your internet connection and try again';

      default:
        return 'Unable to sign in. Please try again.';
    }
  }

  // Re-route to registration screen:
  void openRegistrationScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RegistrationScreen()));
  }

  // Resource cleanup:
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Login screen UI:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to HouseHeld')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: emailController,
                enabled: !isLoading,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                enabled: !isLoading,
                obscureText: obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: obscurePassword
                        ? 'Show Password'
                        : 'Hide Password',
                  ),
                ),
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: 24),

              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton(onPressed: signIn, child: const Text('Sign In')),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: openRegistrationScreen,
                  child: const Text('Don\'t have an account? Create one!'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
