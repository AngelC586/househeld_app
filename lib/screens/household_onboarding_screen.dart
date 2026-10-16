import 'package:flutter/material.dart';

class HouseholdOnboardingScreen extends StatefulWidget {
  final Future<void> Function(String name) onCreate;
  final Future<void> Function(String householdID) onJoin;
  final Future<void> Function() onLogout;

  const HouseholdOnboardingScreen({
    super.key,
    required this.onCreate,
    required this.onJoin,
    required this.onLogout,
  });

  @override
  State<HouseholdOnboardingScreen> createState() =>
      _HouseholdOnboardingScreenState();
}

class _HouseholdOnboardingScreenState extends State<HouseholdOnboardingScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool creating}) async {
    if (_isLoading) return;

    final value = creating ? _nameController.text.trim() : _idController.text.trim();

    if (value.isEmpty) {
      setState(() {
        _errorMessage = creating
            ? 'Please enter a household name.'
            : 'Please enter a household ID.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (creating) {
        await widget.onCreate(value);
      } else {
        await widget.onJoin(value);
      }
    } catch (error) {
      if (mounted) return;

      setState(() {
        _errorMessage = error is StateError ? error.message.toString() : 'Unable to ${creating ? 'create' : 'join'} the household. '
          'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onLogout();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to sign out. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to HouseHeld'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _logout,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Set up your household',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a household or join one using an ID '
                    'shared with you.',
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Create a household',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Household name',
                      hintText: 'Our Apartment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submit(creating: true),
                    child: const Text('Create household'),
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 24),

                  Text(
                    'Join a household',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idController,
                    enabled: !_isLoading,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Household ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submit(creating: false),
                    child: const Text('Join household'),
                  ),

                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
      ),
    );
  }
}