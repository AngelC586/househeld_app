import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class HouseholdService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  HouseholdService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Retrieve a household using its unique document ID.
  Future<Household?> getHousehold(String householdID) async {
    final document = await _db
        .collection('households')
        .doc(householdID)
        .get();

    final data = document.data();

    if (data == null) {
      return null;
    }

    return Household.fromMap(document.id, data);
  }

  // Create a household and its initial data together.
  Future<Household> createHousehold(String householdName) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before creating a household.');
    }

    final name = householdName.trim();

    if (name.isEmpty) {
      throw ArgumentError('Please enter a household name.');
    }

    final userRef = _db.collection('users').doc(user.uid);

    // Firestore generates the household's unique ID.
    final householdRef = _db.collection('households').doc();

    final memberRef = householdRef.collection('members').doc(user.uid);

    final household = Household(
      householdID: householdRef.id,
      householdName: name,
      creatorID: user.uid,
    );

    await _db.runTransaction((transaction) async {
      // Read the profile before writing any documents.
      final userDocument = await transaction.get(userRef);
      final userData = userDocument.data();

      if (userData == null) {
        throw StateError(
          'Your user profile is not ready yet. Please try again.',
        );
      }

      final existingHouseholdID = userData['householdID'];

      if (existingHouseholdID != null &&
          existingHouseholdID != '') {
        throw StateError('You already belong to a household.');
      }

      // Create the household.
      transaction.set(householdRef, household.toMap());

      // Give the creator the Manager role.
      transaction.set(memberRef, {
        'userID': user.uid,
        'householdID': householdRef.id,
        'memberRole': 'manager',
      });

      // Link the user's profile to their household.
      transaction.update(userRef, {
        'householdID': householdRef.id,
      });

      // Initialize the shared household-items list.
      transaction.set(
        householdRef.collection('householdItemsLists').doc('default'),
        {
          'listName': 'Household Items',
          'listVisibility': 'shared',
        },
      );

      // Initialize the shared grocery list.
      transaction.set(
        householdRef.collection('groceryLists').doc('default'),
        {
          'groceryListName': 'Grocery List',
          'groceryListVisibility': 'shared',
          'ownerMemberID': null,
        },
      );

      // Initialize the creator's private personal-items list.
      transaction.set(
        memberRef.collection('personalItemsLists').doc('default'),
        {
          'listName': 'Personal Items',
          'listVisibility': 'private',
          'ownerMemberID': user.uid,
        },
      );
    });

    return household;
  }

  // Join an existing household using its unique document ID.
  Future<void> joinHousehold(String householdID) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before joining a household.');
    }

    final id = householdID.trim();

    if (id.isEmpty || id.contains('/')) {
      throw StateError('Please enter a valid household ID.');
    }

    final userRef = _db.collection('users').doc(user.uid);
    final householdRef = _db.collection('households').doc(id);
    final memberRef = householdRef.collection('members').doc(user.uid);

    await _db.runTransaction((transaction) async {
      // Complete all reads before writing any documents.
      final userDocument = await transaction.get(userRef);
      final userData = userDocument.data();

      if (userData == null) {
        throw StateError(
          'Your user profile is not ready yet. Please try again.',
        );
      }

      final existingHouseholdID = userData['householdID'];

      if (existingHouseholdID != null &&
          existingHouseholdID != '') {
        throw StateError('You already belong to a household.');
      }

      final householdDocument = await transaction.get(householdRef);

      if (!householdDocument.exists) {
        throw StateError('No household found with the provided ID.');
      }

      // Avoid overwriting an existing membership.
      final memberDocument = await transaction.get(memberRef);

      if (memberDocument.exists) {
        throw StateError('You already have a membership here, but your profile '
          'is missing its household link. Please contact your team '
          'to correct the profile.',
        );
      }

      // People joining an existing householdstart as Members.
      transaction.set(memberRef, {
        'userID': user.uid,
        'householdID': id,
        'memberRole': 'member',
      });

      // Link the user's profile to the household.
      transaction.update(userRef, {
        'householdID': id,
      });

      // Give the new member a private personal-items list.
      transaction.set(
        memberRef.collection('personalItemsLists').doc('default'),
        {
          'listName': 'Personal Items',
          'listVisibility': 'private',
          'ownerMemberID': user.uid,
        },
      );
    });
  }
}