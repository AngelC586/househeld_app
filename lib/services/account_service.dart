import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:characters/characters.dart';

import '../models.dart';

// Account Service is in charge of database operations for the "Account" tab
// in the Menu Screen (i.e. viewing and changing account details)
class AccountService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  AccountService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Get current user (ensure they're signed in too):
  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    return user;
  }

  // User document reference:
  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _db.collection('users').doc(uid);
  }

  // Watch the current user's profile:
  Stream<UserProfile?> watchCurrentProfile() {
    final user = _requireUser();

    return _profileRef(user.uid).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) return null;

      return UserProfile.fromMap(snapshot.id, data);
    });
  }

  // Retrieve a household member's information (visible to managers only):
  Future<UserProfile?> getMemberProfile(String memberID) async {
    _requireUser();

    final snapshot = await _profileRef(memberID).get();
    final data = snapshot.data();

    if (data == null) return null;

    return UserProfile.fromMap(snapshot.id, data);
  }

  // Method to update your username:
  Future<void> updateUsername(String newUsername) async {
    final user = _requireUser();
    final username = newUsername.trim();

    if (username.length < 3 || username.length > 30) {
      throw ArgumentError('Username must be 3-30 characters.');
    }

    await _profileRef(user.uid).update({'username': username});
  }

  // Method to update your display name app-wide:
  Future<void> updateDisplayName(String newDisplayName) async {
    final user = _requireUser();
    final name = newDisplayName.trim();

    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Display name must be 1=100 characters.');
    }

    final profileRef = _profileRef(user.uid);

    await _db.runTransaction((transaction) async {
      final profileSnapshot = await transaction.get(profileRef);

      final profileData = profileSnapshot.data();

      if (profileData == null) {
        throw StateError('User profile not found...');
      }

      final householdID = profileData['householdID'] as String?;

      DocumentReference<Map<String, dynamic>>? memberRef;

      if (householdID != null && householdID.isNotEmpty) {
        memberRef = _db
            .collection('households')
            .doc(householdID)
            .collection('members')
            .doc(user.uid);

        final memberSnapshot = await transaction.get(memberRef);

        if (!memberSnapshot.exists) {
          throw StateError('Your household membership was not found...');
        }
      }

      transaction.update(profileRef, {'displayName': name});

      if (memberRef != null) {
        transaction.update(memberRef, {'displayName': name});
      }
    });
  }

  // Method to update your avatar symbol and color:
  Future<void> updateAvatar({
    required String? symbol,
    required int colorValue,
  }) async {
    final user = _requireUser();

    final cleanedSymbol = symbol?.trim();

    if (cleanedSymbol != null && cleanedSymbol.isEmpty) {
      throw ArgumentError('Avatar symbol cannot be empty.');
    }

    // Accepts up to 32 UTF-16 code units, for emojis:
    if (cleanedSymbol != null) {
      if (cleanedSymbol.characters.length != 1 || cleanedSymbol.length > 32) {
        throw ArgumentError('Choose only one letter, number, or emoji.');
      }
    }

    // Color code validation for avatar color:
    if (colorValue < 0 || colorValue > 0xFFFFFFFF) {
      throw ArgumentError('Invalid avatar color.');
    }

    final profileRef = _profileRef(user.uid);

    await _db.runTransaction((transaction) async {
      final profileSnapshot = await transaction.get(profileRef);

      final profileData = profileSnapshot.data();

      if (profileData == null) {
        throw StateError('User profile not found...');
      }

      final householdID = profileData['householdID'] as String?;

      DocumentReference<Map<String, dynamic>>? memberRef;

      if (householdID != null && householdID.isNotEmpty) {
        memberRef = _db
            .collection('households')
            .doc(householdID)
            .collection('members')
            .doc(user.uid);

        final memberSnapshot = await transaction.get(memberRef);

        if (!memberSnapshot.exists) {
          throw StateError('Your household membership was not found...');
        }
      }

      // If symbol is null, use the default symbol
      final updates = <String, dynamic>{
        'avatarColor': colorValue,
        'avatarSymbol': cleanedSymbol ?? FieldValue.delete(),
      };

      transaction.update(profileRef, updates);

      if (memberRef != null) {
        transaction.update(memberRef, updates);
      }
    });
  }

  // Helper to re-authenticate the user when changing their password:
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    final user = _requireUser();

    if (currentPassword.isEmpty) {
      throw ArgumentError('Please enter your current password.');
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw StateError('No email address is associated with this account.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Method to update your password (requires current password):
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final user = _requireUser();

    if (newPassword.length < 6) {
      throw ArgumentError('New password must contain at least 6 characters.');
    }

    if (newPassword != confirmPassword) {
      throw ArgumentError('Passwords do not match.');
    }

    await reauthenticateWithPassword(currentPassword);

    await user.updatePassword(newPassword);
  }

  // Helper to request email change:
  // (Requires an actual valid email to verify!)
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _requireUser();
    final email = newEmail.trim();

    if (email.isEmpty || !email.contains('@')) {
      throw ArgumentError('Please enter a valid email address.');
    }

    if (email == user.email) {
      return;
    }

    await reauthenticateWithPassword(currentPassword);

    // Sends verification email; Email doesn't update until verified!
    await user.verifyBeforeUpdateEmail(email);
  }

  // Method to update database with new email after successful verification:
  Future<void> syncVerifiedEmail() async {
    final user = _requireUser();

    await user.reload();

    final refreshedUser = _requireUser();
    final currentEmail = refreshedUser.email;

    if (currentEmail == null || currentEmail.isEmpty) {
      return;
    }

    final profileRef = _profileRef(refreshedUser.uid);
    final snapshot = await profileRef.get();

    if (!snapshot.exists) {
      throw StateError('User profile not found...');
    }

    if (snapshot.data()?['email'] != currentEmail) {
      await profileRef.update({'email': currentEmail});
    }
  }

  // Method to send password reset email (for login screen's 'Forgot Password'):
  Future<void> sendPasswordResetEmail(String email) async {
    final address = email.trim();

    if (address.isEmpty || !address.contains('@')) {
      throw ArgumentError('Please enter a valid email address.');
    }

    await _auth.sendPasswordResetEmail(email: address);
  }

  // Tiny method to sign out the user (via menu screen):
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Method to delete your account:
  Future<void> deleteAccount({required String currentPassword}) async {
    final user = _requireUser();
    final uid = user.uid;

    await reauthenticateWithPassword(currentPassword);

    final profileRef = _db.collection('users').doc(uid);
    final profileSnapshot = await profileRef.get();
    final originalProfile = profileSnapshot.data();

    if (originalProfile == null) {
      throw StateError('Your account was not found...');
    }

    final householdID = originalProfile['householdID'] as String?;

    DocumentReference<Map<String, dynamic>>? householdRef;
    DocumentReference<Map<String, dynamic>>? memberRef;

    if (householdID != null && householdID.isNotEmpty) {
      householdRef = _db.collection('households').doc(householdID);
      memberRef = householdRef.collection('members').doc(uid);
    }

    await _db.runTransaction((transaction) async {
      final currentProfile = await transaction.get(profileRef);

      if (!currentProfile.exists) {
        throw StateError('Your profile no longer exists...');
      }

      if (memberRef != null && householdRef != null) {
        final currentHouseholdRef = householdRef;
        final currentMemberRef = memberRef;
        final formerMemberRef = currentHouseholdRef
            .collection('formerMembers')
            .doc(uid);

        final householdSnapshot = await transaction.get(currentHouseholdRef);
        final memberSnapshot = await transaction.get(currentMemberRef);

        final memberData = memberSnapshot.data();
        final householdData = householdSnapshot.data();

        if (householdData == null || memberData == null) {
          throw StateError(
            'Your household membership could not be verified...',
          );
        }

        final role = memberData['memberRole'];

        if (role == 'manager') {
          final count = householdData['managerCount'];

          if (count is! int || count <= 1) {
            throw StateError(
              'You are the last remaining Manager. '
              'Please assign another Manager before '
              'attempting to delete your account!',
            );
          }

          transaction.update(currentHouseholdRef, {'managerCount': count - 1});
        }

        transaction.delete(currentMemberRef);
        transaction.set(formerMemberRef, {
          'userID': uid,
          'departedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.delete(profileRef);
    });

    try {
      await user.delete();
    } catch (error) {
      // Restore a profile so the authenticated user can access onboarding:
      final restoredProfile = Map<String, dynamic>.from(originalProfile)
        ..remove('householdID');

      try {
        await profileRef.set(restoredProfile);
      } catch (_) {
        throw StateError(
          'Account deletion did not finish and '
          'profile recovery also failed. '
          'Original error: $error',
        );
      }

      throw StateError(
        'Your account was not deleted, but your household '
        'membership was removed. You can sign in and join '
        'a household again. Error: $error',
      );
    }
  }
}
