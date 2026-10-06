import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onBypass});

  final VoidCallback? onBypass;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final displayNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? errorMessage;
  bool isLoading = false;

  // Sign in existing user:
  Future<void> signIn() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Pass credentials to Firebase Auth:
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Catch incorrect username or password:
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });

      // Successful sign in:
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Register new user:
  Future<void> register() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Pass credentials to Firebase Auth:
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );

      final user = credential.user;

      if (user == null) {
        throw Exception('Account was created, but no user was returned.');
      }

      // Set credentials in database:
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'displayName': displayNameController.text.trim(),
      });

      // Catch existing user errors:
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });

      // Catch Firebase errors:
    } on FirebaseException catch (e) {
      setState(() {
        errorMessage = e.message;
      });

      // Catch other errors:
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });

      // Successful registration and sign in:
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Login Screen UI:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HouseHeld Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Username input:
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),

            // Display Name input:
            const SizedBox(height: 16),
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),

            // Email input:
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            // Password input:
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),

            // Print error messages:
            if (errorMessage != null)
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 16),

            // Loading circle:
            if (isLoading)
              const CircularProgressIndicator()
            else ...[
              // Sign In button:
              ElevatedButton(onPressed: signIn, child: const Text('Sign In')),

              // Create Account button:
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: register,
                child: const Text('Create Account'),
              ),

              // Bypass button (will be removed later):
              if (widget.onBypass != null) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: widget.onBypass,
                  child: const Text('Skip Sign-In (Debug Mode)'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
