import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';

// Account Dialogs are the pop-ups that appear when managing your
// account in the "Account" tab of the Menu screen.

class AccountDialogs {
  const AccountDialogs._();

  static String errorText(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'The current password is incorrect.';
        case 'weak-password':
          return 'Please choose a stronger password.';
        case 'email-already-in-use':
          return 'That email is already in use.';
        case 'requires-recent-login':
          return 'Please sign in again before retrying.';
        case 'network-request-failed':
          return 'Connection failed. Please try again.';
        default:
          return error.message ?? 'Authentication failed.';
      }
    }
    return error.toString();
  }

  // Helper to execute actions:
  static Future<void> execute(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorText(error))));
    }
  }

  // Reusable text box input dialog:
  static Future<String?> textDialog(
    BuildContext context, {
    required String title,
    required String label,
    required String initialValue,
    int maxLength = 100,
  }) async {
    var value = initialValue;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          maxLength: maxLength,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Change username dialog:
  static Future<void> editUsername(
    BuildContext context,
    AccountService service,
    UserProfile profile,
  ) async {
    final value = await textDialog(
      context,
      title: 'Change Username',
      label: 'Username',
      initialValue: profile.username,
      maxLength: 30,
    );

    if (!context.mounted || value == null || value == profile.username) return;

    await execute(
      context,
      () => service.updateUsername(value),
      'Username updated!',
    );
  }

  // Change display name dialog:
  static Future<void> editDisplayName(
    BuildContext context,
    AccountService service,
    UserProfile profile,
  ) async {
    final value = await textDialog(
      context,
      title: 'Change Display Name',
      label: 'Display Name',
      initialValue: profile.displayName,
      maxLength: 100,
    );

    if (!context.mounted || value == null || value == profile.displayName) {
      return;
    }

    await execute(
      context,
      () => service.updateDisplayName(value),
      'Display name updated!',
    );
  }

  // Change password dialog:
  static Future<void> changePassword(
    BuildContext context,
    AccountService service,
  ) async {
    var current = '';
    var next = '';
    var confirm = '';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                onChanged: (v) => current = v,
              ),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                onChanged: (v) => next = v,
              ),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                onChanged: (v) => confirm = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (!context.mounted || submitted != true) return;

    await execute(
      context,
      () => service.changePassword(
        currentPassword: current,
        newPassword: next,
        confirmPassword: confirm,
      ),
      'Password changed successfully!',
    );
  }

  // Change email dialog (will require verification):
  static Future<void> changeEmail(
    BuildContext context,
    AccountService service,
    UserProfile profile,
  ) async {
    var email = profile.email;
    var password = '';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Email'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A verification email will be sent to your new address.  '
                'You must verify your new address before it is changed.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: profile.email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'New Email'),
                onChanged: (v) => email = v,
              ),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                onChanged: (v) => password = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Verification'),
          ),
        ],
      ),
    );

    if (!context.mounted || submitted != true) return;

    await execute(
      context,
      () => service.requestEmailChange(
        newEmail: email,
        currentPassword: password,
      ),
      'Check your new email address for verification.',
    );
  }

  // Avatar customization dialog:
  static Future<void> customizeAvatar(
    BuildContext context,
    AccountService service,
    UserProfile profile,
  ) async {
    const colors = <int>[
      0xFF2F4B3C, // Forest
      0xFFC99A3E, // Mustard
      0xFFA85C56, // Clay
      0xFF1F3428, // Deep Forest
      0xFF5B6156, // Slate
      0xFF347A77, // Teal
    ];

    var value = profile.avatarColor ?? colors.first;
    var symbol = profile.avatarSymbol ?? '';

    int red() => (value >> 16) & 255;
    int green() => (value >> 8) & 255;
    int blue() => value & 255;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          void setChannel(int r, int g, int b) {
            refresh(() {
              value = 0xFF000000 | (r << 16) | (g << 8) | b;
            });
          }

          return AlertDialog(
            title: const Text('Customize Avatar'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Color(value),
                    child: Text(
                      symbol.trim().isEmpty
                          ? (profile.displayName.isEmpty
                                ? '?'
                                : profile.displayName[0].toUpperCase())
                          : symbol,
                      style: const TextStyle(color: Colors.white, fontSize: 27),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: symbol,
                    decoration: const InputDecoration(
                      labelText: 'One letter or emoji',
                      hintText: '(Leave blank for default initial)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => refresh(() => symbol = v),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final colorValue in colors)
                        InkWell(
                          onTap: () => refresh(() => value = colorValue),
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: Color(colorValue),
                            child: value == colorValue
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Custom Color'),
                  Slider(
                    value: red().toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: 'Red: ${red()}',
                    onChanged: (v) => setChannel(v.round(), green(), blue()),
                  ),
                  Slider(
                    value: green().toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: 'Green: ${green()}',
                    onChanged: (v) => setChannel(red(), v.round(), blue()),
                  ),
                  Slider(
                    value: blue().toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: 'Blue: ${blue()}',
                    onChanged: (v) => setChannel(red(), green(), v.round()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final cleaned = symbol.trim();

                  if (cleaned.isNotEmpty &&
                      (cleaned.characters.length != 1 || cleaned.length > 32)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter one letter or emoji.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (!context.mounted || saved != true) return;

    await execute(
      context,
      () => service.updateAvatar(
        symbol: symbol.trim().isEmpty ? null : symbol.trim(),
        colorValue: value,
      ),
      'Avatar updated!',
    );
  }

  // Delete account dialog:
  static Future<void> deleteAccount(
    BuildContext context,
    AccountService service,
  ) async {
    var confirmation = '';
    var password = '';

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Permanently Delete Account?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account will be deleted and you '
                  'will lose household access. This cannot '
                  'be undone.\n\n'
                  'If you are the last remaining Manager, '
                  'you must assign another Manager first!',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                  ),
                  onChanged: (v) => refresh(() => confirmation = v),
                ),
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                  ),
                  onChanged: (v) => refresh(() => password = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.clay),
              onPressed: confirmation == 'DELETE' && password.isNotEmpty
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || submitted != true) return;

    try {
      await service.deleteAccount(currentPassword: password);

      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorText(error))));
    }
  }
}
