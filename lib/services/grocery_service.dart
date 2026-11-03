import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

// Grocery Service class for Grocery Firestore operations:
class GroceryService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  GroceryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String _requireUserID() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to access Grocery.');
    }

    return user.uid;
  }

  void _validateHouseholdID(String householdID) {
    if (householdID.isEmpty || householdID.contains('/')) {
      throw StateError('A valid household ID is required.');
    }
  }

  CollectionReference<Map<String, dynamic>> _lists(String householdID) {
    return _db
        .collection('households')
        .doc(householdID)
        .collection('groceryLists');
  }

  // Listen to all lists that the signed-in user is allowed to see:
  Stream<List<GroceryList>> watchVisibleLists(String householdID) {
    final String userID;

    try {
      userID = _requireUserID();
      _validateHouseholdID(householdID);
    } catch (error) {
      return Stream<List<GroceryList>>.error(error);
    }

    final listsRef = _lists(householdID);

    final queries = [
      listsRef.where('groceryListVisibility', isEqualTo: 'shared'),
      listsRef.where('ownerMemberID', isEqualTo: userID),
      listsRef.where('visibleMemberIDs', arrayContains: userID),
    ];

    // Each query will maintain its latest result,
    // Updates after all three have delivered their intial snapshot:
    final controller = StreamController<List<GroceryList>>();

    final latest = List<List<GroceryList>?>.filled(3, null);

    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void publish() {
      if (controller.isClosed || latest.any((result) => result == null)) {
        return;
      }

      final unique = <String, GroceryList>{};

      for (final result in latest) {
        for (final list in result!) {
          if (list.canView(userID)) {
            unique[list.groceryListID] = list;
          }
        }
      }

      final visible = unique.values.toList()
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) {
            return a.isDefault ? -1 : 1;
          }

          final comparison = a.groceryListName.toLowerCase().compareTo(
            b.groceryListName.toLowerCase(),
          );

          return comparison != 0
              ? comparison
              : a.groceryListID.compareTo(b.groceryListID);
        });

      controller.add(visible);
    }

    controller.onListen = () {
      for (var index = 0; index < queries.length; index++) {
        final queryIndex = index;

        subscriptions.add(
          queries[index].snapshots().listen(
            (snapshot) {
              latest[queryIndex] = snapshot.docs
                  .map((doc) => GroceryList.fromMap(doc.id, doc.data()))
                  .toList();

              publish();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
          ),
        );
      }
    };

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  // Read one Grocery List by ID
  Stream<GroceryList?> watchList({
    required String householdID,
    required String groceryListID,
  }) {
    try {
      _requireUserID();
      _validateHouseholdID(householdID);

      if (groceryListID.isEmpty || groceryListID.contains('/')) {
        throw StateError('A valid Grocery List ID is required.');
      }
    } catch (error) {
      return Stream<GroceryList?>.error(error);
    }

    return _lists(householdID).doc(groceryListID).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) return null;

      return GroceryList.fromMap(snapshot.id, data);
    });
  }

  // Create a new custom Grocery List;
  // Owner is always the current user,
  // starts as private and incomplete unless
  // visibility is explicitly selected to be otherwise:
  Future<String> createList({
    required String householdID,
    required String name,
    String description = '',
    String visibility = 'restricted',
    List<String> visibleMemberIDs = const [],
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);

    final trimmedName = name.trim();

    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw StateError('List names must be between 1 and 200 characters.');
    }

    if (!['shared', 'restricted'].contains(visibility)) {
      throw StateError('Invalid Grocery List visibility');
    }

    final selectedIDs = visibleMemberIDs.toSet().toList();

    if (selectedIDs.length > 8 ||
        selectedIDs.any((id) => id.isEmpty || id.contains('/'))) {
      throw StateError('Select up to 8 valid household members.');
    }

    // Shared lists do not require selected IDs:
    if (visibility == 'shared' && selectedIDs.isNotEmpty) {
      throw StateError('Shared lists cannot have selected members.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(userID);

    final listRef = _lists(householdID).doc();

    final list = GroceryList(
      groceryListID: listRef.id,
      groceryListName: trimmedName,
      groceryListDescription: description.trim(),
      groceryListStatus: groceryListIncomplete,
      groceryListVisibility: visibility,
      ownerMemberID: userID,
      visibleMemberIDs: selectedIDs,
    );

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);

      if (!membership.exists) {
        throw StateError('You are not a member of this household...');
      }

      for (final memberID in selectedIDs) {
        final selectedMember = await transaction.get(
          householdRef.collection('members').doc(memberID),
        );

        if (!selectedMember.exists) {
          throw StateError(
            'A selected household member is no longer available.',
          );
        }
      }

      transaction.set(listRef, list.toMap());
    });

    return listRef.id;
  }

  // Edit an existing custom list:
  Future<void> updateList({
    required String householdID,
    required GroceryList list,
    required String name,
    required String description,
    required String visibility,
    required List<String> visibleMemberIDs,
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);

    if (list.isDefault) {
      throw StateError(
        'Use the "Change Name" option if you want to edit your household Grocery List.',
      );
    }

    if (list.ownerMemberID != userID) {
      throw StateError('Only the list creator can edit its details.');
    }

    final trimmedName = name.trim();

    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw StateError('List names must be between 1 and 200 characters.');
    }

    if (!['shared', 'restricted'].contains(visibility)) {
      throw StateError('Invalid Grocery List visibility.');
    }

    final selectedIDs = visibleMemberIDs.toSet().toList();

    if (selectedIDs.length > 8 ||
        selectedIDs.any((id) => id.isEmpty || id.contains('/'))) {
      throw StateError('Select up to 8 valid household members.');
    }

    if (visibility == 'shared' && selectedIDs.isNotEmpty) {
      throw StateError('Shared lists cannot have selected members.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final listRef = _lists(householdID).doc(list.groceryListID);

    await _db.runTransaction<void>((transaction) async {
      final existing = await transaction.get(listRef);

      final data = existing.data();

      if (data == null) {
        throw StateError('This Grocery List no longer exists.');
      }

      if (data['ownerMemberID'] != userID) {
        throw StateError('You can no longer edit this list.');
      }

      for (final memberID in selectedIDs) {
        final member = await transaction.get(
          householdRef.collection('members').doc(memberID),
        );

        if (!member.exists) {
          throw StateError(
            'A selected household member is no longer available.',
          );
        }
      }

      transaction.update(listRef, {
        'groceryListName': trimmedName,
        'groceryListDescription': description.trim(),
        'groceryListVisibility': visibility,
        'visibleMemberIDs': selectedIDs,
      });
    });
  }

  CollectionReference<Map<String, dynamic>> _items(
    String householdID,
    String groceryListID,
  ) {
    return _lists(householdID).doc(groceryListID).collection('items');
  }

  // A couple of data validation methods:
  void _validateListID(String groceryListID) {
    if (groceryListID.isEmpty || groceryListID.contains('/')) {
      throw StateError('A Valid Grocery List ID is required.');
    }
  }

  void _validateItemDetails({
    required String name,
    required String type,
    required int quantity,
  }) {
    if (name.trim().isEmpty || name.trim().length > 200) {
      throw StateError('Item names must be between 1 and 200 characters.');
    }

    if (type.trim().isEmpty) {
      throw StateError('Please enter an item type.');
    }

    if (quantity <= 0) {
      throw StateError('Grocery quantity must be greater than 0');
    }
  }

  // Verify that a list exists and can accept new items:
  Future<int> _checkWritableList(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> listRef,
  ) async {
    final snapshot = await transaction.get(listRef);
    final data = snapshot.data();

    if (data == null) {
      throw StateError('This Grocery List no longer exists.');
    }

    if (data['groceryListStatus'] != groceryListIncomplete) {
      throw StateError(
        'This list is already complete, try reopening it before editing items.',
      );
    }

    final revision = data['groceryItemsRevision'];

    if (revision is! int || revision < 0) {
      throw StateError('This Grocery List has an invalid revision.');
    }

    return revision;
  }

  // Watch Grocery Items method:
  Stream<List<GroceryItem>> watchItems({
    required String householdID,
    required String groceryListID,
  }) {
    try {
      _requireUserID();
      _validateHouseholdID(householdID);
      _validateListID(groceryListID);
    } catch (error) {
      return Stream<List<GroceryItem>>.error(error);
    }

    return _items(householdID, groceryListID).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => GroceryItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Create new Grocery Item:
  Future<String> createItem({
    required String householdID,
    required String groceryListID,
    required String name,
    required String type,
    int quantity = 1,
    String description = '',
  }) async {
    _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);
    _validateItemDetails(name: name, type: type, quantity: quantity);

    final listRef = _lists(householdID).doc(groceryListID);
    final itemRef = _items(householdID, groceryListID).doc();

    final item = GroceryItem(
      groceryItemID: itemRef.id,
      groceryItemName: name.trim(),
      groceryItemType: type.trim(),
      groceryItemQuantity: quantity,
      groceryItemPurchasedQuantity: 0,
      groceryItemStatus: groceryItemUnpurchased,
      groceryItemDescription: description.trim(),
    );

    await _db.runTransaction<void>((transaction) async {
      final listSnapshot = await transaction.get(listRef);
      final listData = listSnapshot.data();

      if (listData == null) {
        throw StateError('This Grocery List no longer exists.');
      }

      if (listData['groceryListStatus'] != groceryListIncomplete) {
        throw StateError(
          'This list is already complete, try reopening it before adding items.',
        );
      }

      final revision = listData['groceryItemsRevision'];

      if (revision is! int || revision < 0) {
        throw StateError('This Grocery List has an invalid revision.');
      }

      // All reads occur before any writes.
      transaction.set(itemRef, item.toMap());

      transaction.update(listRef, {'groceryItemsRevision': revision + 1});
    });

    return itemRef.id;
  }

  // Add an existing Pantry Item:
  Future<void> addPantryItem({
    required String householdID,
    required String groceryListID,
    required String foodItemID,
    int quantity = 1,
  }) async {
    _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (foodItemID.isEmpty || foodItemID.contains('/')) {
      throw StateError('A valid Pantry Item ID is required.');
    }

    if (quantity <= 0) {
      throw StateError('Quantity must be greater than 0.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final pantryRef = householdRef.collection('pantryItems').doc(foodItemID);

    final listRef = _lists(householdID).doc(groceryListID);

    // Match the Pantry Item ID with Grocery Item:
    final itemRef = _items(
      householdID,
      groceryListID,
    ).doc('pantry_$foodItemID');

    await _db.runTransaction<void>((transaction) async {
      final revision = await _checkWritableList(transaction, listRef);
      final pantrySnapshot = await transaction.get(pantryRef);
      final grocerySnapshot = await transaction.get(itemRef);

      final pantryData = pantrySnapshot.data();

      if (pantryData == null) {
        throw StateError('This Pantry Item no longer exists.');
      }

      final pantryItem = PantryItem.fromMap(pantrySnapshot.id, pantryData);

      _validateItemDetails(
        name: pantryItem.foodName,
        type: pantryItem.foodType,
        quantity: quantity,
      );

      final existingData = grocerySnapshot.data();

      if (existingData != null) {
        if (existingData['sourceFoodItemID'] != foodItemID ||
            existingData['sourceHouseholdItemID'] != null) {
          throw StateError('The existing linked Grocery Item is inconsistent.');
        }

        final existing = GroceryItem.fromMap(grocerySnapshot.id, existingData);

        transaction.update(itemRef, {
          'groceryItemName': pantryItem.foodName,
          'groceryItemType': pantryItem.foodType,
          'groceryItemDescription': pantryItem.foodDescription,
          'groceryItemQuantity': existing.groceryItemQuantity + quantity,
          'groceryItemStatus': groceryItemUnpurchased,
          'groceryItemPurchasedQuantity': 0,
        });
      } else {
        final item = GroceryItem(
          groceryItemID: itemRef.id,
          groceryItemName: pantryItem.foodName,
          groceryItemType: pantryItem.foodType,
          groceryItemQuantity: quantity,
          groceryItemPurchasedQuantity: 0,
          groceryItemDescription: pantryItem.foodDescription,
          sourceFoodItemID: foodItemID,
        );

        transaction.set(itemRef, item.toMap());
      }

      transaction.update(listRef, {'groceryItemsRevision': revision + 1});
    });
  }

  // Add an existing "Stuff" item:
  Future<void> addHouseholdStuffItem({
    required String householdID,
    required String groceryListID,
    required String stuffItemID,
    int quantity = 1,
  }) async {
    _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (stuffItemID.isEmpty || stuffItemID.contains('/')) {
      throw StateError('A valid Household Item ID is required.');
    }

    if (quantity <= 0) {
      throw StateError('Quantity must be greater than 0.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final sourceRef = householdRef
        .collection('householdItemsLists')
        .doc('default')
        .collection('items')
        .doc(stuffItemID);

    final listRef = _lists(householdID).doc(groceryListID);

    // Uses stuff_service's existing ID conventions
    final groceryItemID = 'stuff_${Uri.encodeComponent(sourceRef.path)}';

    final itemRef = _items(householdID, groceryListID).doc(groceryItemID);

    await _db.runTransaction<void>((transaction) async {
      final revision = await _checkWritableList(transaction, listRef);

      final sourceSnapshot = await transaction.get(sourceRef);
      final grocerySnapshot = await transaction.get(itemRef);

      final sourceData = sourceSnapshot.data();

      if (sourceData == null) {
        throw StateError('This Household Item no longer exists.');
      }

      final stuffItem = StuffItem.fromMap(sourceSnapshot.id, sourceData);

      if (stuffItem.isPrivate || stuffItem.listType != 'household') {
        throw StateError('Only shared Household Items can be added here.');
      }

      _validateItemDetails(
        name: stuffItem.itemName,
        type: 'Other',
        quantity: quantity,
      );

      final existingData = grocerySnapshot.data();

      if (existingData != null) {
        if (existingData['sourceHouseholdItemID'] != stuffItemID ||
            existingData['sourceFoodItemID'] != null) {
          throw StateError('The existing linked Grocery Item is inconsistent.');
        }

        final existing = GroceryItem.fromMap(grocerySnapshot.id, existingData);

        transaction.update(itemRef, {
          'groceryItemName': stuffItem.itemName,
          'groceryItemDescription': stuffItem.itemDescription,
          'groceryItemQuantity': existing.groceryItemQuantity + quantity,
          'groceryItemStatus': groceryItemUnpurchased,
          'groceryItemPurchasedQuantity': 0,
        });
      } else {
        final item = GroceryItem(
          groceryItemID: itemRef.id,
          groceryItemName: stuffItem.itemName,
          groceryItemType: 'Other',
          groceryItemQuantity: quantity,
          groceryItemPurchasedQuantity: 0,
          groceryItemDescription: stuffItem.itemDescription,
          sourceHouseholdItemID: stuffItemID,
        );

        transaction.set(itemRef, item.toMap());
      }

      transaction.update(listRef, {'groceryItemsRevision': revision + 1});
    });
  }

  // Edit an existing Grocery Item:
  Future<void> updateItem({
    required String householdID,
    required String groceryListID,
    required String groceryItemID,
    required String name,
    required String type,
    required String description,
    required int quantity,
  }) async {
    _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (groceryItemID.isEmpty || groceryItemID.contains('/')) {
      throw StateError('A valid Grocery Item ID is required.');
    }

    _validateItemDetails(name: name, type: type, quantity: quantity);

    final listRef = _lists(householdID).doc(groceryListID);
    final itemRef = _items(householdID, groceryListID).doc(groceryItemID);

    await _db.runTransaction<void>((transaction) async {
      final revision = await _checkWritableList(transaction, listRef);

      final snapshot = await transaction.get(itemRef);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('This Grocery Item no longer exists.');
      }

      if (data['groceryItemStatus'] == groceryItemPurchased) {
        throw StateError(
          'This item has already been purchased, reopen it to edit its quantity.',
        );
      }

      transaction.update(itemRef, {
        'groceryItemName': name.trim(),
        'groceryItemType': type.trim(),
        'groceryItemDescription': description.trim(),
        'groceryItemQuantity': quantity,
        'groceryItemStatus': groceryItemUnpurchased,
      });
      transaction.update(listRef, {'groceryItemsRevision': revision + 1});
    });
  }

  // Update the quantity of an item:
  Future<void> updateItemQuantity({
    required String householdID,
    required String groceryListID,
    required String groceryItemID,
    required int quantity,
  }) async {
    _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (groceryItemID.isEmpty || groceryItemID.contains('/')) {
      throw StateError('A valid Grocery Item ID is required.');
    }

    // Quantity 0 has special purchase/delete behavior
    if (quantity <= 0) {
      throw StateError(
        'Try marking this item as Purchased or deleting it instead.',
      );
    }

    final listRef = _lists(householdID).doc(groceryListID);
    final itemRef = _items(householdID, groceryListID).doc(groceryItemID);

    await _db.runTransaction<void>((transaction) async {
      final revision = await _checkWritableList(transaction, listRef);

      final snapshot = await transaction.get(itemRef);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('This Grocery Item no longer exists.');
      }

      if (data['groceryItemStatus'] == groceryItemPurchased) {
        throw StateError(
          'Mark this item as unpurchased before changing its quantity.',
        );
      }

      transaction.update(itemRef, {'groceryItemQuantity': quantity});
      transaction.update(listRef, {'groceryItemsRevision': revision + 1});
    });
  }

  // Delete an existing Grocery Item:
  Future<void> deleteItem({
    required String householdID,
    required String groceryListID,
    required String groceryItemID,
  }) async {
    _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (groceryItemID.isEmpty || groceryItemID.contains('/')) {
      throw StateError('A valid Grocery Item ID is required.');
    }

    final listRef = _lists(householdID).doc(groceryListID);
    final itemRef = _items(householdID, groceryListID).doc(groceryItemID);

    await _db.runTransaction<void>((transaction) async {
      final listSnapshot = await transaction.get(listRef);
      final listData = listSnapshot.data();

      if (listData == null) {
        throw StateError('This Grocery List no longer exists.');
      }

      if (listData['groceryListStatus'] != groceryListIncomplete) {
        throw StateError('Try reopening this list before deleting items.');
      }

      final revision = listData['groceryItemsRevision'];

      if (revision is! int || revision < 0) {
        throw StateError('This Grocery List has an invalid revision.');
      }

      final itemSnapshot = await transaction.get(itemRef);

      if (!itemSnapshot.exists) {
        throw StateError('This Grocery Item no longer exists.');
      }

      transaction.delete(itemRef);

      transaction.update(listRef, {'groceryItemsRevision': revision + 1});
    });
  }

  // Mark a Grocery Item as 'Purchased':
  Future<void> markItemPurchased({
    required String householdID,
    required String groceryListID,
    required String groceryItemID,
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (groceryItemID.isEmpty || groceryItemID.contains('/')) {
      throw StateError('A valid Grocery Item ID is required.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(userID);

    final listRef = _lists(householdID).doc(groceryListID);

    final itemsRef = _items(householdID, groceryListID);

    final itemRef = itemsRef.doc(groceryItemID);

    final initialListSnapshot = await listRef.get();
    final initialListData = initialListSnapshot.data();

    if (initialListData == null) {
      throw StateError('Grocery List not found.');
    }

    final initialRevision = initialListData['groceryItemsRevision'];

    if (initialRevision is! int || initialRevision < 0) {
      throw StateError('Invalid Grocery List revision.');
    }

    final itemIndex = await itemsRef.get();

    final itemRefs = itemIndex.docs.map((doc) => doc.reference).toList();

    if (!itemRefs.any((ref) => ref.id == groceryItemID)) {
      throw StateError('This Grocery Item no longer exists.');
    }

    await _db.runTransaction<void>((transaction) async {
      final memberSnapshot = await transaction.get(memberRef);

      final listSnapshot = await transaction.get(listRef);

      final grocerySnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final ref in itemRefs) {
        grocerySnapshots.add(await transaction.get(ref));
      }

      if (!memberSnapshot.exists) {
        throw StateError('You are no longer a member of this household.');
      }

      final listData = listSnapshot.data();

      if (listData == null) {
        throw StateError('This Grocery List no longer exists.');
      }

      final list = GroceryList.fromMap(listSnapshot.id, listData);

      final revision = listData['groceryItemsRevision'];

      if (revision is! int || revision < 0) {
        throw StateError('This Grocery List has an invalid revision.');
      }

      if (revision != initialRevision) {
        throw StateError(
          'The Grocery List changed while purchasing, please try again.',
        );
      }

      if (!list.canView(userID)) {
        throw StateError('You do not have access to this Grocery List.');
      }

      if (list.isComplete) {
        throw StateError('This list is already complete...');
      }

      GroceryItem? targetItem;
      var allOthersPurchased = true;

      for (final snapshot in grocerySnapshots) {
        final data = snapshot.data();

        if (data == null) {
          throw StateError(
            'The list changed while purchasing, please try again.',
          );
        }

        final item = GroceryItem.fromMap(snapshot.id, data);

        if (snapshot.id == groceryItemID) {
          targetItem = item;
        } else if (!item.isPurchased) {
          allOthersPurchased = false;
        }
      }

      if (targetItem == null) {
        throw StateError('This Grocery Item no longer exists.');
      }

      final item = targetItem;

      if (item.isPurchased) {
        throw StateError('This item is already purchased...');
      }

      if (item.groceryItemQuantity <= 0) {
        throw StateError('This item has no quantity to purchase.');
      }

      if (item.sourceFoodItemID != null && item.sourceHouseholdItemID != null) {
        throw StateError('A Grocery Item cannot have two sources.');
      }

      DocumentReference<Map<String, dynamic>>? sourceRef;

      DocumentSnapshot<Map<String, dynamic>>? sourceSnapshot;

      if (item.sourceFoodItemID != null) {
        sourceRef = householdRef
            .collection('pantryItems')
            .doc(item.sourceFoodItemID!);

        sourceSnapshot = await transaction.get(sourceRef);
      } else if (item.sourceHouseholdItemID != null) {
        sourceRef = householdRef
            .collection('householdItemsLists')
            .doc('default')
            .collection('items')
            .doc(item.sourceHouseholdItemID!);

        sourceSnapshot = await transaction.get(sourceRef);
      }

      if (sourceRef != null) {
        final sourceData = sourceSnapshot?.data();

        if (sourceData == null) {
          throw StateError('The linked source item no longer exists.');
        }

        if (item.sourceFoodItemID != null) {
          final currentQuantity = sourceData['foodQuantity'];

          if (currentQuantity is! int || currentQuantity < 0) {
            throw StateError('The Pantry quantity is invalid.');
          }

          final updatedQuantity = currentQuantity + item.groceryItemQuantity;

          transaction.update(sourceRef, {
            'foodQuantity': updatedQuantity,
            'foodStockStatus': PantryItem.stockStatusForQuantity(
              updatedQuantity,
            ),
          });
        } else {
          if (sourceData['listType'] != 'household' ||
              sourceData['ownerMemberID'] != '') {
            throw StateError('The linked Household Item is invalid.');
          }

          transaction.update(sourceRef, {'itemStatus': 'available'});
        }
      }

      transaction.update(itemRef, {
        'groceryItemQuantity': 0,
        'groceryItemPurchasedQuantity': item.groceryItemQuantity,
        'groceryItemStatus': groceryItemPurchased,
      });

      // If all items are 'purchased', mark the list as 'complete'.
      transaction.update(listRef, {
        'groceryItemsRevision': revision + 1,
        if (allOthersPurchased)
          'groceryListStatus': list.isDefault
              ? groceryListDefaultComplete
              : groceryListComplete,
      });
    });
  }

  // Mark a Grocery Item as 'unpurchased':
  Future<void> markItemUnpurchased({
    required String householdID,
    required String groceryListID,
    required String groceryItemID,
    required int quantity,
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (groceryItemID.isEmpty || groceryItemID.contains('/')) {
      throw StateError('A valid Grocery Item ID is required.');
    }

    if (quantity <= 0) {
      throw StateError('Please enter a quantity greater than 0.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(userID);

    final listRef = _lists(householdID).doc(groceryListID);

    final itemRef = _items(householdID, groceryListID).doc(groceryItemID);

    await _db.runTransaction<void>((transaction) async {
      final memberSnapshot = await transaction.get(memberRef);

      final listSnapshot = await transaction.get(listRef);

      final itemSnapshot = await transaction.get(itemRef);

      if (!memberSnapshot.exists) {
        throw StateError('You are no longer a household member.');
      }

      final listData = listSnapshot.data();

      if (listData == null) {
        throw StateError('This Grocery List no longer exists.');
      }

      final revision = listData['groceryItemsRevision'];

      if (revision is! int || revision < 0) {
        throw StateError('This Grocery List has an invalid revision.');
      }

      final list = GroceryList.fromMap(listSnapshot.id, listData);

      if (!list.canView(userID)) {
        throw StateError('You do not have access to this Grocery List.');
      }

      final itemData = itemSnapshot.data();

      if (itemData == null) {
        throw StateError('This Grocery Item no longer exists.');
      }

      final item = GroceryItem.fromMap(itemSnapshot.id, itemData);

      if (!item.isPurchased) {
        throw StateError(
          'This item is already unpurchased, try marking it as purchased instead.',
        );
      }

      transaction.update(itemRef, {
        'groceryItemQuantity': quantity,
        'groceryItemPurchasedQuantity': 0,
        'groceryItemStatus': groceryItemUnpurchased,
      });

      // A completed list becomes active again:
      transaction.update(listRef, {
        'groceryItemsRevision': revision + 1,
        if (list.isComplete) 'groceryListStatus': groceryListIncomplete,
      });
    });
  }

  // Method for dismissing the "reset list" prompt for the default list:
  Future<void> dismissDefaultResetPrompt({required String householdID}) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(userID);

    final listRef = _lists(householdID).doc('default');

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);

      final listSnapshot = await transaction.get(listRef);

      if (!membership.exists) {
        throw StateError('You are not a member of this household.');
      }

      final data = listSnapshot.data();

      if (data == null) {
        throw StateError('The default Grocery List does not exist...');
      }

      final status = data['groceryListStatus'];

      if (status == groceryListCompleteNoReset) {
        return;
      }

      if (status != groceryListDefaultComplete) {
        throw StateError(
          'The default Grocery List is not awaiting a reset decision.',
        );
      }

      transaction.update(listRef, {
        'groceryListStatus': groceryListCompleteNoReset,
      });
    });
  }

  // Mark a Grocery List as 'complete':
  Future<void> markListComplete({
    required String householdID,
    required String groceryListID,
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(userID);
    final listRef = _lists(householdID).doc(groceryListID);
    final itemsRef = _items(householdID, groceryListID);

    final initialList = await listRef.get();
    final initialData = initialList.data();

    if (initialData == null) {
      throw StateError('Grocery List not found.');
    }

    if (!GroceryList.fromMap(initialList.id, initialData).canView(userID)) {
      throw StateError('You cannot access this list.');
    }

    final initialRevision = initialData['groceryItemsRevision'];
    if (initialRevision is! int || initialRevision < 0) {
      throw StateError('Invalid Grocery List revision.');
    }

    final itemIndex = await itemsRef.get();

    if (itemIndex.docs.length > 100) {
      throw StateError(
        'This Grocery List is too large, try removing some items first.',
      );
    }

    await _db.runTransaction<void>((transaction) async {
      final member = await transaction.get(memberRef);
      final listSnapshot = await transaction.get(listRef);
      final data = listSnapshot.data();

      if (!member.exists || data == null) {
        throw StateError('Household membership or list unavailable.');
      }

      final list = GroceryList.fromMap(listSnapshot.id, data);

      if (!list.canView(userID)) {
        throw StateError('You cannot access this list.');
      }

      if (list.isComplete) {
        throw StateError('This list is already complete.');
      }

      if (data['groceryItemsRevision'] != initialRevision) {
        throw StateError('The list changed, please try again.');
      }

      final groceryItems = <GroceryItem>[];
      final groceryRefs = <DocumentReference<Map<String, dynamic>>>[];

      for (final doc in itemIndex.docs) {
        final current = await transaction.get(doc.reference);

        if (!current.exists) {
          throw StateError('An item changed, please try again.');
        }

        groceryItems.add(GroceryItem.fromMap(current.id, current.data()!));
        groceryRefs.add(doc.reference);
      }

      final pantryAmounts = <String, int>{};
      final stuffIDs = <String>{};

      for (final item in groceryItems) {
        if (item.isPurchased) continue;

        if (item.groceryItemQuantity <= 0) {
          throw StateError('An unpurchased item has an invalid quantity.');
        }

        if (item.sourceFoodItemID != null &&
            item.sourceHouseholdItemID != null) {
          throw StateError('An item has conflicting sources.');
        }

        if (item.sourceFoodItemID != null) {
          final id = item.sourceFoodItemID!;
          pantryAmounts[id] =
              (pantryAmounts[id] ?? 0) + item.groceryItemQuantity;
        }

        if (item.sourceHouseholdItemID != null) {
          stuffIDs.add(item.sourceHouseholdItemID!);
        }
      }

      final pantrySources = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final stuffSources = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final id in pantryAmounts.keys) {
        pantrySources[id] = await transaction.get(
          householdRef.collection('pantryItems').doc(id),
        );
      }

      for (final id in stuffIDs) {
        stuffSources[id] = await transaction.get(
          householdRef
              .collection('householdItemsLists')
              .doc('default')
              .collection('items')
              .doc(id),
        );
      }

      for (final entry in pantrySources.entries) {
        final source = entry.value;
        final sourceData = source.data();
        if (sourceData == null) {
          throw StateError('A linked Pantry Item is missing.');
        }

        final currentQuantity = sourceData['foodQuantity'];
        if (currentQuantity is! int || currentQuantity < 0) {
          throw StateError('Invalid Pantry inventory quantity.');
        }

        final updated = currentQuantity + pantryAmounts[entry.key]!;

        transaction.update(source.reference, {
          'foodQuantity': updated,
          'foodStockStatus': PantryItem.stockStatusForQuantity(updated),
        });
      }

      for (final source in stuffSources.values) {
        final sourceData = source.data();
        if (sourceData == null ||
            sourceData['listType'] != 'household' ||
            sourceData['ownerMemberID'] != '') {
          throw StateError('A linked Household Item is invalid.');
        }

        transaction.update(source.reference, {'itemStatus': 'available'});
      }

      for (var i = 0; i < groceryItems.length; i++) {
        final item = groceryItems[i];
        if (item.isPurchased) continue;

        transaction.update(groceryRefs[i], {
          'groceryItemQuantity': 0,
          'groceryItemPurchasedQuantity': item.groceryItemQuantity,
          'groceryItemStatus': groceryItemPurchased,
        });
      }

      transaction.update(listRef, {
        'groceryListStatus': list.isDefault
            ? groceryListCompleteNoReset
            : groceryListComplete,
        'groceryItemsRevision': initialRevision + 1,
      });
    });
  }

  // Mark a Grocery List as 'incomplete':
  Future<void> markListIncomplete({
    required String householdID,
    required String groceryListID,
  }) async {
    final userID = _requireUserID();

    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(userID);

    final listRef = _lists(householdID).doc(groceryListID);

    final itemsRef = _items(householdID, groceryListID);

    final initialListSnapshot = await listRef.get();
    final initialData = initialListSnapshot.data();

    if (initialData == null) {
      throw StateError('This Grocery List no longer exists.');
    }

    final initialList = GroceryList.fromMap(
      initialListSnapshot.id,
      initialData,
    );

    if (!initialList.canView(userID)) {
      throw StateError('You do not have access to this Grocery List.');
    }

    if (!initialList.isComplete) {
      throw StateError('This Grocery List is already incomplete.');
    }

    final initialRevision = initialData['groceryItemsRevision'];

    if (initialRevision is! int || initialRevision < 0) {
      throw StateError('This Grocery List has an invalid revision.');
    }

    final itemIndex = await itemsRef.get();

    if (itemIndex.docs.length > 100) {
      throw StateError(
        'This Grocery List is too large, try removing some items first.',
      );
    }

    await _db.runTransaction<void>((transaction) async {
      final memberSnapshot = await transaction.get(memberRef);

      final listSnapshot = await transaction.get(listRef);

      if (!memberSnapshot.exists) {
        throw StateError('You are no longer a household member.');
      }

      final listData = listSnapshot.data();

      if (listData == null) {
        throw StateError('This Grocery List no longer exists.');
      }

      final list = GroceryList.fromMap(listSnapshot.id, listData);

      if (!list.canView(userID)) {
        throw StateError('You do not have access to this Grocery List.');
      }

      if (!list.isComplete) {
        throw StateError('This list is already incomplete.');
      }

      final currentRevision = listData['groceryItemsRevision'];

      if (currentRevision is! int || currentRevision != initialRevision) {
        throw StateError(
          'This Grocery List changed. '
          'Please refresh and try again.',
        );
      }

      final currentItems = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final document in itemIndex.docs) {
        currentItems.add(await transaction.get(document.reference));
      }

      if (currentItems.any((item) => !item.exists)) {
        throw StateError(
          'The Grocery List changed while reopening. '
          'Please try again.',
        );
      }

      for (final snapshot in currentItems) {
        final data = snapshot.data()!;

        final item = GroceryItem.fromMap(snapshot.id, data);

        if (!item.isPurchased) {
          continue;
        }

        final newQuantity = item.groceryItemPurchasedQuantity > 0
            ? item.groceryItemPurchasedQuantity
            : 1;

        transaction.update(snapshot.reference, {
          'groceryItemQuantity': newQuantity,
          'groceryItemPurchasedQuantity': 0,
          'groceryItemStatus': groceryItemUnpurchased,
        });
      }

      transaction.update(listRef, {
        'groceryListStatus': groceryListIncomplete,
        'groceryItemsRevision': currentRevision + 1,
      });
    });
  }

  // Copy the default Grocery List's items (can be used as a preset):
  Future<String> copyList({
    required String householdID,
    required String sourceListID,
    required String name,
    String description = '',
    String visibility = 'restricted',
    List<String> visibleMemberIDs = const [],
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(sourceListID);

    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw StateError('List names must be 1-200 characters.');
    }

    if (!['shared', 'restricted'].contains(visibility)) {
      throw StateError('Invalid visibility.');
    }

    final selected = visibleMemberIDs.toSet().toList();

    if (selected.length > 8 ||
        selected.any((id) => id.isEmpty || id.contains('/')) ||
        (visibility == 'shared' && selected.isNotEmpty)) {
      throw StateError('Invalid member selection.');
    }

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(userID);
    final sourceRef = _lists(householdID).doc(sourceListID);
    final destinationRef = _lists(householdID).doc();

    final initialList = await sourceRef.get();
    final initialData = initialList.data();

    if (initialData == null) {
      throw StateError('Source Grocery List not found.');
    }

    if (!GroceryList.fromMap(initialList.id, initialData).canView(userID)) {
      throw StateError('You cannot copy this list.');
    }

    final revision = initialData['groceryItemsRevision'];
    if (revision is! int || revision < 0) {
      throw StateError('Invalid source list revision.');
    }

    final index = await sourceRef.collection('items').get();

    if (index.docs.length > 100) {
      throw StateError(
        'This Grocery List is too large, try removing some items first.',
      );
    }

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);
      final source = await transaction.get(sourceRef);
      final sourceData = source.data();

      if (!membership.exists || sourceData == null) {
        throw StateError('Membership or source list unavailable.');
      }

      if (!GroceryList.fromMap(source.id, sourceData).canView(userID)) {
        throw StateError('You cannot copy this list.');
      }

      if (sourceData['groceryItemsRevision'] != revision) {
        throw StateError('The source list changed, please try again.');
      }

      for (final id in selected) {
        final member = await transaction.get(
          householdRef.collection('members').doc(id),
        );
        if (!member.exists) {
          throw StateError('A selected member is unavailable.');
        }
      }

      final copies = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in index.docs) {
        final current = await transaction.get(doc.reference);
        if (!current.exists) {
          throw StateError('The source items changed.');
        }
        copies.add(current);
      }

      final allPurchased =
          copies.isNotEmpty &&
          copies.every(
            (doc) => doc.data()?['groceryItemStatus'] == groceryItemPurchased,
          );

      final newList = GroceryList(
        groceryListID: destinationRef.id,
        groceryListName: trimmedName,
        groceryListDescription: description.trim(),
        groceryListVisibility: visibility,
        ownerMemberID: userID,
        visibleMemberIDs: selected,
        groceryListStatus: allPurchased
            ? groceryListComplete
            : groceryListIncomplete,
        groceryItemsRevision: copies.length,
      );

      transaction.set(destinationRef, newList.toMap());

      for (final original in copies) {
        transaction.set(
          destinationRef.collection('items').doc(original.id),
          Map<String, dynamic>.from(original.data()!),
        );
      }
    });

    return destinationRef.id;
  }

  // Delete a custom Grocery List:
  Future<void> deleteList({
    required String householdID,
    required String groceryListID,
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);
    _validateListID(groceryListID);

    if (groceryListID == 'default') {
      throw StateError('The default list cannot be deleted.');
    }

    final listRef = _lists(householdID).doc(groceryListID);
    final initial = await listRef.get();
    final data = initial.data();

    if (data == null) {
      throw StateError('Grocery List not found.');
    }

    if (data['ownerMemberID'] != userID) {
      throw StateError('Only the creator can delete this list.');
    }

    final revision = data['groceryItemsRevision'];
    if (revision is! int || revision < 0) {
      throw StateError('Invalid list revision.');
    }

    final index = await listRef.collection('items').get();
    if (index.docs.length > 100) {
      throw StateError(
        'This Grocery List is too long, try removing some items first.',
      );
    }

    await _db.runTransaction<void>((transaction) async {
      final current = await transaction.get(listRef);
      final currentData = current.data();

      if (currentData == null || currentData['ownerMemberID'] != userID) {
        throw StateError('You cannot delete this list.');
      }

      if (currentData['groceryItemsRevision'] != revision) {
        throw StateError('The list changed, please try again.');
      }

      final currentItems = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in index.docs) {
        final item = await transaction.get(doc.reference);
        if (!item.exists) {
          throw StateError('The list changed. Please retry.');
        }
        currentItems.add(item);
      }

      for (final item in currentItems) {
        transaction.delete(item.reference);
      }

      transaction.delete(listRef);
    });
  }

  // Reset the default Grocery List:
  Future<void> resetDefaultList({required String householdID}) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(userID);
    final listRef = _lists(householdID).doc('default');

    final initial = await listRef.get();
    final data = initial.data();

    if (data == null) {
      throw StateError('Default Grocery List not found.');
    }

    final revision = data['groceryItemsRevision'];
    if (revision is! int || revision < 0) {
      throw StateError('Invalid default-list revision.');
    }

    final index = await listRef.collection('items').get();

    if (index.docs.length > 100) {
      throw StateError(
        'Your household Grocery List is too large, try removing some items first.',
      );
    }

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);
      final current = await transaction.get(listRef);
      final currentData = current.data();

      if (!membership.exists || currentData == null) {
        throw StateError('Membership or default list unavailable.');
      }

      if (currentData['groceryItemsRevision'] != revision) {
        throw StateError('The list changed, please try again.');
      }

      final currentItems = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in index.docs) {
        final item = await transaction.get(doc.reference);
        if (!item.exists) {
          throw StateError('The list changed, please try again.');
        }
        currentItems.add(item);
      }

      for (final item in currentItems) {
        transaction.delete(item.reference);
      }

      transaction.update(listRef, {
        'groceryListStatus': groceryListIncomplete,
        'groceryItemsRevision': revision + 1,
      });
    });
  }

  // Change the default Grocery List's name:
  Future<void> renameDefaultList({
    required String householdID,
    required String name,
  }) async {
    final userID = _requireUserID();
    _validateHouseholdID(householdID);

    final trimmedName = name.trim();

    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw StateError('List names must be between 1 and 200 characters.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(userID);

    final listRef = _lists(householdID).doc('default');

    await _db.runTransaction<void>((transaction) async {
      final membership = await transaction.get(memberRef);
      final listSnapshot = await transaction.get(listRef);

      if (!membership.exists) {
        throw StateError('You are not a member of this household.');
      }

      if (!listSnapshot.exists) {
        throw StateError('The default Grocery List does not exist...');
      }

      transaction.update(listRef, {'groceryListName': trimmedName});
    });
  }

  // Shopping Trip method to commit all changes in a single transaction:
  Future<void> purchaseSelectedItems({
    required String householdID,
    required String groceryListID,
    required List<String> itemIDs,
  }) async {
    final uid = _requireUserID();

    _validateHouseholdID(householdID);

    _validateListID(groceryListID);

    final selected = itemIDs.toSet();

    if (selected.isEmpty) return;

    // Currently caps Shopping Trip items to 20:
    if (selected.length > 20 ||
        selected.any((id) => id.isEmpty || id.contains('/'))) {
      throw StateError('Select at most 20 valid items per shopping trip.');
    }

    final householdRef = _db.collection('households').doc(householdID);

    final memberRef = householdRef.collection('members').doc(uid);

    final listRef = _lists(householdID).doc(groceryListID);

    final listBefore = await listRef.get();

    final beforeData = listBefore.data();

    if (beforeData == null) throw StateError('Grocery List not found.');

    final revision = beforeData['groceryItemsRevision'];

    if (revision is! int || revision < 0) {
      throw StateError('Invalid list revision.');
    }

    final index = await _items(householdID, groceryListID).get();

    // Currently can only shop with lists <= 60 items long:
    if (index.docs.length > 60) {
      throw StateError(
        'This Grocery List is too large, try removing some items first.',
      );
    }

    if (!selected.every((id) => index.docs.any((doc) => doc.id == id))) {
      throw StateError('The item selection has changed, please try again.');
    }

    await _db.runTransaction<void>((transaction) async {
      final member = await transaction.get(memberRef);

      final listSnapshot = await transaction.get(listRef);

      final data = listSnapshot.data();

      if (!member.exists || data == null) {
        throw StateError('Membership or list unavailable.');
      }

      final list = GroceryList.fromMap(listSnapshot.id, data);

      if (!list.canView(uid)) throw StateError('You cannot access this list.');

      if (list.isComplete) {
        throw StateError('This Grocery List is already complete!.');
      }

      if (data['groceryItemsRevision'] != revision) {
        throw StateError('The list changed, please try again.');
      }

      final items = <GroceryItem>[];

      final refs = <DocumentReference<Map<String, dynamic>>>[];

      for (final doc in index.docs) {
        final snap = await transaction.get(doc.reference);

        if (!snap.exists) {
          throw StateError('An item was removed, please try again.');
        }

        items.add(GroceryItem.fromMap(snap.id, snap.data()!));
        refs.add(doc.reference);
      }

      final pantryQuantities = <String, int>{};

      final stuffIDs = <String>{};

      var anyToPurchase = false;

      var allPurchasedAfter = items.isNotEmpty;

      for (final item in items) {
        if (item.isPurchased) continue;
        if (!selected.contains(item.groceryItemID)) {
          allPurchasedAfter = false;
          continue;
        }

        anyToPurchase = true;

        if (item.groceryItemQuantity <= 0) {
          throw StateError('Invalid item quantity.');
        }

        if (item.sourceFoodItemID != null &&
            item.sourceHouseholdItemID != null) {
          throw StateError('An item has two sources.');
        }

        if (item.sourceFoodItemID != null) {
          final id = item.sourceFoodItemID!;

          pantryQuantities[id] =
              (pantryQuantities[id] ?? 0) + item.groceryItemQuantity;
        }

        if (item.sourceHouseholdItemID != null) {
          stuffIDs.add(item.sourceHouseholdItemID!);
        }
      }

      final pantrySources = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final stuffSources = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final id in pantryQuantities.keys) {
        pantrySources[id] = await transaction.get(
          householdRef.collection('pantryItems').doc(id),
        );
      }

      for (final id in stuffIDs) {
        stuffSources[id] = await transaction.get(
          householdRef
              .collection('householdItemsLists')
              .doc('default')
              .collection('items')
              .doc(id),
        );
      }

      // This is where all selected items are committed to the database:
      for (final entry in pantrySources.entries) {
        final source = entry.value;
        final quantity = source.data()?['foodQuantity'];

        if (quantity is! int || quantity < 0) {
          throw StateError('Linked Pantry Item is missing or invalid.');
        }

        final total = quantity + pantryQuantities[entry.key]!;

        transaction.update(source.reference, {
          'foodQuantity': total,
          'foodStockStatus': PantryItem.stockStatusForQuantity(total),
        });
      }

      for (final source in stuffSources.values) {
        final details = source.data();

        if (details == null ||
            details['listType'] != 'household' ||
            details['ownerMemberID'] != '') {
          throw StateError('Linked Household Item is unavailable.');
        }

        transaction.update(source.reference, {'itemStatus': 'available'});
      }

      for (var i = 0; i < items.length; i++) {
        final item = items[i];

        if (item.isPurchased || !selected.contains(item.groceryItemID)) {
          continue;
        }

        transaction.update(refs[i], {
          'groceryItemQuantity': 0,
          'groceryItemPurchasedQuantity': item.groceryItemQuantity,
          'groceryItemStatus': groceryItemPurchased,
        });
      }

      if (anyToPurchase) {
        transaction.update(listRef, {
          'groceryItemsRevision': revision + 1,
          if (allPurchasedAfter)
            'groceryListStatus': list.isDefault
                ? groceryListDefaultComplete
                : groceryListComplete,
        });
      }
    });
  }
}
