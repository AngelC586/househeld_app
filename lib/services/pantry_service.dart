import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

// Allows created pantry items to be saved to the database:
class PantryService {
  final FirebaseFirestore _db;

  PantryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _pantryItems(String householdID) {
    return _db
        .collection('households')
        .doc(householdID)
        .collection('pantryItems');
  }

  Stream<List<PantryItem>> watchPantryItems(String householdID) {
    return _pantryItems(householdID).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PantryItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> createPantryItem({
    required String householdID,
    required String foodName,
    required String foodType,
    required int foodQuantity,
    required String foodDescription,
  }) async {
    if (foodQuantity < 0) {
      throw ArgumentError('Quantity cannot be negative!');
    }

    final item = PantryItem(
      foodItemID: '',
      foodName: foodName.trim(),
      foodType: foodType,
      foodQuantity: foodQuantity,
      foodStockStatus: PantryItem.stockStatusForQuantity(foodQuantity),
      foodDescription: foodDescription.trim(),
    );

    await _pantryItems(householdID).add(item.toMap());
  }

  Future<void> updatePantryItem({
    required String householdID,
    required PantryItem item,
  }) async {
    if (item.foodQuantity < 0) {
      throw ArgumentError('Quantity cannot be negative!');
    }

    await _pantryItems(householdID).doc(item.foodItemID).update(item.toMap());

    await _updateLinkedGroceryDescriptions(
      householdID: householdID,
      item: item,
    );
  }

  Future<void> updateQuantity({
    required String householdID,
    required String foodItemID,
    required int quantity,
  }) async {
    if (quantity < 0) {
      throw ArgumentError('Quantity cannot be negative!');
    }

    await _pantryItems(householdID).doc(foodItemID).update({
      'foodQuantity': quantity,
      'foodStockStatus': PantryItem.stockStatusForQuantity(quantity),
    });
  }

  Future<void> markOutOfStock({
    required String householdID,
    required String foodItemID,
  }) {
    return updateQuantity(
      householdID: householdID,
      foodItemID: foodItemID,
      quantity: 0,
    );
  }

  Future<void> deletePantryItem({
    required String householdID,
    required String foodItemID,
  }) async {
    final groceryLists = await _db
        .collection('households')
        .doc(householdID)
        .collection('groceryLists')
        .get();

    final batch = _db.batch();

    batch.delete(_pantryItems(householdID).doc(foodItemID));

    for (final groceryList in groceryLists.docs) {
      final linkedItems = await groceryList.reference
          .collection('items')
          .where('sourceFoodItemID', isEqualTo: foodItemID)
          .get();

      for (final linkedItem in linkedItems.docs) {
        batch.update(linkedItem.reference, {'sourceFoodItemID': null});
      }
    }

    await batch.commit();
  }

  // When a pantry item gets updated, so does its linked grocery item:
  Future<void> _updateLinkedGroceryDescriptions({
    required String householdID,
    required PantryItem item,
  }) async {
    final groceryLists = await _db
        .collection('households')
        .doc(householdID)
        .collection('groceryLists')
        .get();

    final batch = _db.batch();
    var hasUpdates = false;

    for (final groceryList in groceryLists.docs) {
      final linkedItems = await groceryList.reference
          .collection('items')
          .where('sourceFoodItemID', isEqualTo: item.foodItemID)
          .get();

      for (final linkedItem in linkedItems.docs) {
        hasUpdates = true;

        batch.update(linkedItem.reference, {
          'groceryItemName': item.foodName,
          'groceryItemType': item.foodType,
          'groceryItemDescription': item.foodDescription,
        });
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  // Method for allowing a pantry item to get added to a grocery list:
  Future<void> addToDefaultGroceryList({
    required String householdID,
    required PantryItem pantryItem,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Grocery quantity must be greater than 0');
    }

    final groceryListRef = _db
        .collection('households')
        .doc(householdID)
        .collection('groceryLists')
        .doc('default');

    final groceryItemRef = groceryListRef
        .collection('items')
        .doc('pantry_${pantryItem.foodItemID}');

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(groceryItemRef);

      // If the item is already in a grocery list, update quantity:
      if (existing.exists) {
        final currentQuantity =
            existing.data()?['groceryItemQuantity'] as int? ?? 0;

        transaction.update(groceryItemRef, {
          'groceryItemQuantity': currentQuantity + quantity,
          'groceryItemStatus': 'unpurchased',
        });

        return;
      }

      transaction.set(groceryItemRef, {
        'groceryItemName': pantryItem.foodName,
        'groceryItemType': pantryItem.foodType,
        'groceryItemQuantity': quantity,
        'groceryItemStatus': 'unpurchased',
        'groceryItemDescription': pantryItem.foodDescription,
        'sourceFoodItemID': pantryItem.foodItemID,
        'sourceHouseholdItemID': null,
      });
    });
  }
}
