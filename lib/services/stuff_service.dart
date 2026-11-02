import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class StuffService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  StuffService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance, 
      _auth = auth ?? FirebaseAuth.instance;

  String _requireUserID() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to access your items.');
    }

    return user.uid;
  }

  void _validateList(String householdID, String listType) {
    if (householdID.isEmpty || householdID.contains('/')) {
      throw StateError('A valid household ID is required');
    }

    if (listType != 'household' && listType != 'private'){
      throw StateError('Please choose a valid items list.');
    }
  }

  CollectionReference<Map<String, dynamic>> _items({
    required String householdID,
    required String listType,
    required String userID,
  }) {
    final householdRef = _db.collection('households').doc(householdID);

    if (listType == 'private') {
      return householdRef
        .collection('members')
        .doc(userID)
        .collection('personalItemsLists')
        .doc('default')
        .collection('items');
    }

    return householdRef
      .collection('householdItemsLists')
      .doc('default')
      .collection('items');
  }

  // Save a new item and return its Firestore document ID.
  Future<String> createItem({
    required String householdID,
    required String listType,
    required String name,
    String description = '',
    String status = 'available',
  }) async {
    final userID = _requireUserID();
    _validateList(householdID, listType);

    final trimmedName = name.trim();

    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw StateError('Item names must be between 1 and 200 characters');
    }

    if (!['available', 'low', 'out_of_stock'].contains(status)) {
      throw StateError('Please choose a valid item status.');
    }

    final memberRef = _db
      .collection('households')
      .doc(householdID)
      .collection('members')
      .doc(userID);

    final itemRef = _items(
      householdID: householdID,
      listType: listType,
      userID: userID,
    ).doc();

    final item = StuffItem(
      itemId: itemRef.id, 
      itemName: trimmedName,
      itemDescription: description.trim(),
      itemStatus: status, 
      listType: listType, 
      ownerMemberID: listType == 'private' ? userID : '',
    );

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);
      final role = membership.data()?['memberRole'];

      if(!['manager', 'member', 'child'].contains(role)) {
        throw StateError('Your household membership could not be verified.');
      }

      if (listType == 'household' &&
        role != 'manager' && 
        role != 'member') {
          throw StateError('Only Managers and Members can add shared household items.',
          );
      }

        transaction.set(itemRef, item.toMap());
    });

    return itemRef.id;    
  }

  Future<void> updateItem({
    required String householdID,
    required StuffItem item,
  }) async {
    final userID = _requireUserID();
    _validateList(householdID, item.listType);

    if (item.itemId.isEmpty || item.itemId.contains('/')) {
      throw StateError('A valid item ID is required.');
    }

    final name = item.itemName.trim();

    if (name.isEmpty || name.length > 200) {
      throw StateError('Item names must be between 1 and 200 characters.');
    }

    if (!['available', 'low', 'out_of_stock'].contains(item.itemStatus)) {
      throw StateError('Please choose a valid item status.');
    }

    if (item.isPrivate && item.ownerMemberID != userID) {
      throw StateError('You can only edit your own private items.');
    }

    final memberRef = _db
      .collection('households')
      .doc(householdID)
      .collection('members')
      .doc(userID);

    final itemRef = _items(
      householdID: householdID, 
      listType: item.listType, 
      userID: userID,
      ).doc(item.itemId);

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);
      final role = membership.data()?['memberRole'];

      if (!['manager', 'member', 'child'].contains(role)) {
        throw StateError('Your household membership could not be verified.');
      }

      if (item.listType == 'household' && 
          role != 'manager' &&
          role != 'member') {
            throw StateError('Only Managers and Members can edit shared household items.',
            );
        }

      final document = await transaction.get(itemRef);
      final data = document.data();

      if (data == null) {
        throw StateError('This item no longer exists.');
      }

      final expectedOwner = item.isPrivate ? userID : '';

      if (data['listType'] != item.listType || data['ownerMemberID'] != expectedOwner) {
        throw StateError('This item has inconsistent ownership information.');
      }

      // Preserve the item's list and owner 
      transaction.update(itemRef, {
        'itemName': name,
        'itemDescription': item.itemDescription.trim(),
        'itemStatus': item.itemStatus,
      });
    });
  }

  Future<bool> updateStatus({
    required String householdID,
    required StuffItem item,
    required String status,
  }) async {
    final userID = _requireUserID();
    _validateList(householdID, item.listType);

    if (item.itemId.isEmpty || item.itemId.contains('/')){
      throw StateError("A valid item ID is required.");
    }

    if (!['available', 'low', 'out_of_stock'].contains(status)){
      throw StateError('Please choose a valid item status.');
    }

    if (item.isPrivate && item.ownerMemberID != userID) {
      throw StateError('You can only update your own private items.');
    }

    final memberRef = _db
      .collection('households')
      .doc(householdID)
      .collection('members')
      .doc(userID);

    final itemRef = _items(
      householdID: householdID,
      listType: item.listType,
      userID: userID,
    ).doc(item.itemId);

    return _db.runTransaction<bool>((transaction) async {
      final membership = await transaction.get(memberRef);
      final role = membership.data()?['memberRole'];

      if (!['manager', 'member', 'child'].contains(role)) {
        throw StateError('Your household membership could not be verified.');
      }

      if (item.listType == 'household' &&
          role != 'manager' && 
          role != 'member') {
            throw StateError('Only Managers and Members can update shared household items.');
          }

      final document = await transaction.get(itemRef);
      final data = document.data();

      if(data == null){
        throw StateError('This item no longer exists.');
      }

      final expectedOwner = item.isPrivate ? userID : '';

      if (data['listType'] != item.listType || 
          data['ownerMemberID'] != expectedOwner) {
            throw StateError('This item has inconsistent ownership information');
      }

      final previousStatus = data['itemStatus'];

      if (previousStatus == status) {
        return false;
      }

      transaction.update(itemRef, {
        'itemStatus': status,
      });

      return status == 'out_of_stock';
    });
  }

  // Listen to the selected shared or private list
  Stream<List<StuffItem>> watchItems({
    required String householdID,
    required String listType,
  }) {
    try {
      final userID = _requireUserID();
      _validateList(householdID, listType);

      return _items(
        householdID: householdID, 
        listType: listType, 
        userID: userID,
      ).snapshots().map(
        (snapshot) => snapshot.docs
          .map(
            (document) => StuffItem.fromMap(
              document.id,
              document.data(),
            ),
      )
      .toList(),
      );
    } catch (error) {
      return Stream<List<StuffItem>>.error(error);
    }
  }

  Future<void> deleteItem({
    required String householdID,
    required StuffItem item,
  }) async {
    final userID = _requireUserID();
    _validateList(householdID, item.listType);

    if (item.itemId.isEmpty || item.itemId.contains('/')) {
      throw StateError('A valid item ID is required.');
    }

    if (item.isPrivate && item.ownerMemberID != userID) {
      throw StateError('You can only delete your own private items.');
    }

    final memberRef = _db
      .collection('households')
      .doc(householdID)
      .collection('members')
      .doc(userID);

    final itemRef = _items(
      householdID: householdID,
      listType: item.listType,
      userID: userID,
    ).doc(item.itemId);

    await _db.runTransaction<void>((transaction) async{
      final membership = await transaction.get(memberRef);
      final role = membership.data()?['memberRole'];

      if (!['manager', 'member', 'child'].contains(role)) {
        throw StateError('Your household membership could not be verified.');
      }

      if (item.listType == 'household' &&
          role != 'manager' &&
          role != 'member') {
        throw StateError(
          'Only Managers and Members can delete shared household items.',
        );
      }

      final document = await transaction.get(itemRef);
      final data = document.data();

      if (data == null) {
        throw StateError('This item no longer exists.');
      }

      final expectedOwner = item.isPrivate ? userID : '';

      if (data['listType'] != item.listType ||
          data['ownerMemberID'] != expectedOwner) {
        throw StateError('This item has inconsistent ownership information.');
      }

      transaction.delete(itemRef);
    });
  }

  Future<void> addToDefaultGroceryList({
    required String householdID,
    required StuffItem item,
    required int quantity,
  }) async {
    final userID = _requireUserID();
    _validateList(householdID, item.listType);

    if (item.itemId.isEmpty || item.itemId.contains('/')) {
      throw StateError('A valid item ID is required.');
    }

    if (quantity <= 0) {
      throw StateError('Grocery quantity must be greater than 0.');
    }

    if (item.isPrivate && item.ownerMemberID != userID) {
      throw StateError('You can only share your own private items.');
    }

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(userID);

    final itemRef = _items(
      householdID: householdID,
      listType: item.listType,
      userID: userID,
    ).doc(item.itemId);

    // Use the source path to distinguish items from different lists.
    // Encoding keeps the slashes out of the grocery document ID.
    final groceryItemID = 'stuff_${Uri.encodeComponent(itemRef.path)}';

    final groceryItemRef = householdRef
        .collection('groceryLists')
        .doc('default')
        .collection('items')
        .doc(groceryItemID);

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);
      final role = membership.data()?['memberRole'];

      if (!['manager', 'member', 'child'].contains(role)) {
        throw StateError('Your household membership could not be verified.');
      }

      if (!item.isPrivate && role != 'manager' && role != 'member') {
        throw StateError(
          'Only Managers and Members can add shared household items '
          'to groceries.',
        );
      }

      final sourceDocument = await transaction.get(itemRef);
      final sourceData = sourceDocument.data();

      if (sourceData == null) {
        throw StateError('This item no longer exists.');
      }

      final expectedOwner = item.isPrivate ? userID : '';

      if (sourceData['listType'] != item.listType ||
          sourceData['ownerMemberID'] != expectedOwner) {
        throw StateError('This item has inconsistent ownership information.');
      }

      final sourceItem = StuffItem.fromMap(
        sourceDocument.id,
        sourceData,
      );

      final groceryDocument = await transaction.get(groceryItemRef);
      final groceryData = groceryDocument.data();

      if (groceryData != null) {
        final currentQuantity = groceryData['groceryItemQuantity'];

        if (currentQuantity is! int || currentQuantity < 0) {
          throw StateError('The existing grocery quantity is invalid.');
        }

        transaction.update(groceryItemRef, {
          'groceryItemName': sourceItem.itemName,
          'groceryItemDescription': sourceItem.itemDescription,
          'groceryItemQuantity': currentQuantity + quantity,
          'groceryItemStatus': 'unpurchased',
        });
      } else {
        transaction.set(groceryItemRef, {
          'groceryItemName': sourceItem.itemName,
          'groceryItemType': 'Other',
          'groceryItemQuantity': quantity,
          'groceryItemStatus': 'unpurchased',
          'groceryItemDescription': sourceItem.itemDescription,
          'sourceFoodItemID': null,
          'sourceHouseholdItemID': item.isPrivate ? null : item.itemId,
        });
      }
    });
  }
}