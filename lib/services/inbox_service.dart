import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class InboxService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  InboxService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String _requireUserID() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to access your Inbox.');
    }

    return user.uid;
  }

  void _validateID(String id) {
    if (id.isEmpty || id.contains('/')) {
      throw StateError('A valid document ID is required.');
    }
  }

  CollectionReference<Map<String, dynamic>> _members(String householdID) {
    _validateID(householdID);

    return _db.collection('households').doc(householdID).collection('members');
  }

  CollectionReference<Map<String, dynamic>> _myMessages(String householdID) {
    final userID = _requireUserID();
    return _members(householdID).doc(userID).collection('messages');
  }

  // Listen to the signed-in user's messages, newest first.
  Stream<List<InboxMessage>> watchMessages(String householdID) {
    try {
      return _myMessages(householdID)
          .orderBy('sentAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => InboxMessage.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (error) {
      return Stream<List<InboxMessage>>.error(error);
    }
  }

  // Send one independent message copy to each selected recipient.
  Future<void> sendMessage({
    required String householdID,
    required String subject,
    required String body,
    required List<String> recipientIDs,
  }) async {
    final userID = _requireUserID();
    final membersRef = _members(householdID);

    final trimmedSubject = subject.trim();
    final trimmedBody = body.trim();
    final recipients = recipientIDs.toSet().toList();

    if (trimmedSubject.isEmpty || trimmedSubject.length > 50) {
      throw StateError('Enter a subject between 1 and 50 characters.');
    }

    if (trimmedBody.isEmpty || trimmedBody.length > 500) {
      throw StateError('Enter a message between 1 and 500 characters.');
    }

    if (recipients.isEmpty || recipients.length > 8) {
      throw StateError('Select between 1 and 8 recipients.');
    }

    for (final recipientID in recipients) {
      _validateID(recipientID);
    }

    final senderRef = membersRef.doc(userID);
    final messageID = senderRef.collection('messages').doc().id;

    await _db.runTransaction<void>((transaction) async {
      final sender = await transaction.get(senderRef);
      final role = sender.data()?['memberRole'];

      if (!['manager', 'member'].contains(role)) {
        throw StateError('Only Managers and Members can send messages.');
      }

      // Check every recipient before writing any message copies.
      for (final recipientID in recipients) {
        final recipient = await transaction.get(membersRef.doc(recipientID));

        if (!recipient.exists) {
          throw StateError(
            'A selected household member is no longer available.',
          );
        }
      }

      final data = <String, dynamic>{
        'subject': trimmedSubject,
        'body': trimmedBody,
        'sentByMemberID': userID,
        'sentToMemberIDs': recipients,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      for (final recipientID in recipients) {
        final messageRef = membersRef
            .doc(recipientID)
            .collection('messages')
            .doc(messageID);

        transaction.set(messageRef, data);
      }
    });
  }

  // Change only the signed-in user's copy.
  Future<void> setRead({
    required String householdID,
    required String messageID,
    required bool isRead,
  }) async {
    _validateID(messageID);

    await _myMessages(householdID).doc(messageID).update({'isRead': isRead});
  }

  // Delete only the signed-in user's copy.
  Future<void> deleteMessage({
    required String householdID,
    required String messageID,
  }) async {
    _validateID(messageID);

    await _myMessages(householdID).doc(messageID).delete();
  }
}
