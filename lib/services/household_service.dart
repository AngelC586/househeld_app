import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class HouseholdService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  HouseholdService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Retrieve a household using its unique document ID.
  Future<Household?> getHousehold(String householdID) async {
    final document = await _db.collection('households').doc(householdID).get();

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
      managerCount: 1,
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

      if (existingHouseholdID != null && existingHouseholdID != '') {
        throw StateError('You already belong to a household.');
      }

      // Create the household.
      transaction.set(householdRef, household.toMap());

      // Give the creator the Manager role.
      transaction.set(memberRef, {
        'userID': user.uid,
        'householdID': householdRef.id,
        'memberRole': 'manager',
        'displayName': userData['displayName'] as String? ?? '',
        if (userData['avatarSymbol'] != null)
          'avatarSymbol': userData['avatarSymbol'],
        if (userData['avatarColor'] != null)
          'avatarColor': userData['avatarColor'],
      });

      // Link the user's profile to their household.
      transaction.update(userRef, {'householdID': householdRef.id});

      // Initialize the shared household-items list.
      transaction.set(
        householdRef.collection('householdItemsLists').doc('default'),
        {'listName': 'Household Items', 'listVisibility': 'shared'},
      );

      // Initialize the shared grocery list.
      transaction.set(householdRef.collection('groceryLists').doc('default'), {
        'groceryListName': 'Grocery List',
        'groceryListStatus': 'incomplete',
        'groceryListDescription': '',
        'groceryListVisibility': 'shared',
        'ownerMemberID': null,
        'visibleMemberIDs': <String>[],
        'groceryItemsRevision': 0,
      });

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

      if (existingHouseholdID != null && existingHouseholdID != '') {
        throw StateError('You already belong to a household.');
      }

      final householdDocument = await transaction.get(householdRef);

      if (!householdDocument.exists) {
        throw StateError('No household found with the provided ID.');
      }

      // Avoid overwriting an existing membership.
      final memberDocument = await transaction.get(memberRef);

      if (memberDocument.exists) {
        throw StateError(
          'You already have a membership here, but your profile '
          'is missing its household link. Please contact your team '
          'to correct the profile.',
        );
      }

      // People joining an existing householdstart as Members.
      transaction.set(memberRef, {
        'userID': user.uid,
        'householdID': id,
        'memberRole': 'member',
        'displayName': userData['displayName'] as String? ?? '',
        if (userData['avatarSymbol'] != null)
          'avatarSymbol': userData['avatarSymbol'],
        if (userData['avatarColor'] != null)
          'avatarColor': userData['avatarColor'],
      });

      // Link the user's profile to the household.
      transaction.update(userRef, {'householdID': id});

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

  // Listen for household members and their display names.
  Stream<List<HouseholdMember>> watchMembers(String householdID) {
    if (_auth.currentUser == null) {
      return Stream<List<HouseholdMember>>.error(
        StateError('Please sign in to view household members.'),
      );
    }

    if (householdID.isEmpty || householdID.contains('/')) {
      return Stream<List<HouseholdMember>>.error(
        StateError('A valid household ID is required.'),
      );
    }

    return _db
        .collection('households')
        .doc(householdID)
        .collection('members')
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs.map((document) {
            final data = document.data();

            return HouseholdMember(
              userID: document.id,
              householdID: householdID,
              memberRole: data['memberRole'] as String? ?? 'member',
              displayName: data['displayName'] as String? ?? '',
              avatarSymbol: data['avatarSymbol'] as String?,
              avatarColor: data['avatarColor'] as int?,
            );
          }).toList();

          members.sort((a, b) {
            final comparison = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );

            return comparison != 0 ? comparison : a.userID.compareTo(b.userID);
          });

          return members;
        });
  }

  // Menu Screen related methods:

  // Watch household info to display it in real time:
  Stream<Household?> watchHousehold(String householdID) {
    return _db.collection('households').doc(householdID).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();

      if (data == null) return null;

      return Household.fromMap(snapshot.id, data);
    });
  }

  // Watch the signed-in member's household membership:
  Stream<HouseholdMember?> watchCurrentMember(String householdID) {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return Stream<HouseholdMember?>.error(
        StateError('Please sign in first.'),
      );
    }

    return _db
        .collection('households')
        .doc(householdID)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();

          if (data == null) return null;

          return HouseholdMember.fromMap(data);
        });
  }

  // Method to rename the household (Managers only):
  Future<void> renameHousehold({
    required String householdID,
    required String newName,
  }) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Please sign in first.');
    }

    final name = newName.trim();

    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Household name must be 1-100 characters.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(uid);

    await _db.runTransaction((transaction) async {
      final memberSnapshot = await transaction.get(memberRef);

      final householdSnapshot = await transaction.get(householdRef);

      if (!householdSnapshot.exists) {
        throw StateError('Household not found...');
      }

      if (memberSnapshot.data()?['memberRole'] != 'manager') {
        throw StateError('Only Managers can rename the household.');
      }

      transaction.update(householdRef, {'householdName': name});
    });
  }

  // Method for changing a household member's role (also manager only):
  Future<void> changeMemberRole({
    required String householdID,
    required String memberID,
    required String newRole,
  }) async {
    final currentUID = _auth.currentUser?.uid;

    if (currentUID == null) {
      throw StateError('Please sign in first.');
    }

    if (!['manager', 'member', 'child'].contains(newRole)) {
      throw ArgumentError('Invalid household role.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final actorRef = householdRef.collection('members').doc(currentUID);

    final targetRef = householdRef.collection('members').doc(memberID);

    await _db.runTransaction((transaction) async {
      final householdSnapshot = await transaction.get(householdRef);

      final actorSnapshot = await transaction.get(actorRef);

      final targetSnapshot = memberID == currentUID
          ? actorSnapshot
          : await transaction.get(targetRef);

      final householdData = householdSnapshot.data();
      final actorData = actorSnapshot.data();
      final targetData = targetSnapshot.data();

      if (householdData == null) {
        throw StateError('Household not found.');
      }

      if (actorData?['memberRole'] != 'manager') {
        throw StateError('Only managers can change other members\' roles.');
      }

      if (targetData == null) {
        throw StateError('Household member not found.');
      }

      final oldRole = targetData['memberRole'] as String;

      if (oldRole == newRole) return;

      // Multiple managers ARE allowed, but a household must have at least 1
      // The code blocks below checks for that:
      final managerCount = householdData['managerCount'];

      if (managerCount is! int || managerCount < 1) {
        throw StateError('Household Manager count could not be determined.');
      }

      var updatedCount = managerCount;

      if (oldRole == 'manager') {
        updatedCount--;
      }

      if (newRole == 'manager') {
        updatedCount++;
      }

      if (updatedCount < 1) {
        throw StateError('A household must have at least one manager!');
      }

      // Commit updated role:
      transaction.update(targetRef, {'memberRole': newRole});

      // Also update manager count if it changed:
      if (updatedCount != managerCount) {
        transaction.update(householdRef, {'managerCount': updatedCount});
      }
    });
  }

  // Method for handling removing members:
  Future<void> removeMember({
    required String householdID,
    required String memberID,
  }) async {
    final actorID = _auth.currentUser?.uid;

    if (actorID == null) {
      throw StateError('Please sign in first.');
    }

    if (actorID == memberID) {
      throw StateError(
        'If you want to remove youself, use the \'Leave Household\' option instead.',
      );
    }

    await _detachMember(
      householdID: householdID,
      memberID: memberID,
      requireManager: true,
    );
  }

  // Method for handling leaving a household:
  Future<void> leaveHousehold({required String householdID}) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Please sign in first.');
    }

    await _detachMember(
      householdID: householdID,
      memberID: uid,
      requireManager: false,
    );
  }

  // Helper for detaching members from their household (in the DB):
  Future<void> _detachMember({
    required String householdID,
    required String memberID,
    required bool requireManager,
  }) async {
    final actorID = _auth.currentUser?.uid;

    if (actorID == null) {
      throw StateError('Please sign in first.');
    }

    if (householdID.isEmpty ||
        householdID.contains('/') ||
        memberID.isEmpty ||
        memberID.contains('/')) {
      throw ArgumentError('Invalid household or member ID');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final actorRef = householdRef.collection('members').doc(actorID);

    final targetRef = householdRef.collection('members').doc(memberID);

    final profileRef = _db.collection('users').doc(memberID);

    // Make sure the last manager can't remove themselves:
    final currentHousehold = await householdRef.get();
    final currentTarget = await targetRef.get();

    final currentManagerCount = currentHousehold.data()?['managerCount'];

    final currentTargetRole = currentTarget.data()?['memberRole'];

    if (currentTargetRole == 'manager' &&
        currentManagerCount is int &&
        currentManagerCount <= 1) {
      throw StateError(
        'You cannot remove the last remaining Manager. '
        'Please assign another Manager first.',
      );
    }

    await _db.runTransaction((transaction) async {
      final householdSnapshot = await transaction.get(householdRef);

      final actorSnapshot = await transaction.get(actorRef);

      final targetSnapshot = actorID == memberID
          ? actorSnapshot
          : await transaction.get(targetRef);

      final profileSnapshot = await transaction.get(profileRef);

      final householdData = householdSnapshot.data();
      final actorData = actorSnapshot.data();
      final targetData = targetSnapshot.data();
      final profileData = profileSnapshot.data();

      if (householdData == null ||
          actorData == null ||
          targetData == null ||
          profileData == null) {
        throw StateError('Household, membership, or profile not found...');
      }

      final actorRole = actorData['memberRole'] as String? ?? 'member';

      final targetRole = targetData['memberRole'] as String? ?? 'member';

      if (requireManager && actorRole != 'manager') {
        throw StateError('Only managers can remove household members.');
      }

      if (!requireManager) {
        if (actorID != memberID) {
          throw StateError('You can only leave for your own account.');
        }

        if (actorRole == 'child') {
          throw StateError('Child accounts cannot leave their household.');
        }
      }

      if (profileData['householdID'] != householdID) {
        throw StateError('This user profile does not match the household.');
      }

      final managerCount = householdData['managerCount'];

      if (managerCount is! int || managerCount < 1) {
        throw StateError('Household Manager count could not be determined.');
      }

      // Additional check for the final manager:
      final targetIsManager = targetRole == 'manager';

      if (targetIsManager && managerCount <= 1) {
        throw StateError(
          'The last remaining Manager and cannot leave or be removed. '
          'Please assign another Manager first.',
        );
      }

      // This removes the user's household link:
      transaction.update(profileRef, {'householdID': FieldValue.delete()});

      // This removes their membership from the household:
      transaction.delete(targetRef);

      // Update the manager count if one gets removed:
      if (targetIsManager) {
        transaction.update(householdRef, {'managerCount': managerCount - 1});
      }

      // NOTE: Currently, removing a member or leaving a household does NOT
      // delete their private stuff list or its items from the database!
    });
  }
}
