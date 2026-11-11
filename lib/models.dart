import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String email;
  final String displayName;
  final String? householdID;

  // Optional avatar customization variables:
  final String? avatarSymbol;
  final int? avatarColor;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    required this.displayName,
    this.householdID,
    this.avatarSymbol,
    this.avatarColor,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      householdID: data['householdID'] as String?,
      avatarSymbol: data['avatarSymbol'] as String?,
      avatarColor: data['avatarColor'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'username': username,
    'email': email,
    'displayName': displayName,
    if (householdID != null) 'householdID': householdID,
    if (avatarSymbol != null) 'avatarSymbol': avatarSymbol,
    if (avatarColor != null) 'avatarColor': avatarColor,
  };
}

class Household {
  final String householdID;
  final String householdName;
  final String creatorID;
  final int? managerCount;

  const Household({
    required this.householdID,
    required this.householdName,
    required this.creatorID,
    this.managerCount,
  });

  factory Household.fromMap(String householdID, Map<String, dynamic> data) {
    return Household(
      householdID: householdID,
      householdName: data['householdName'] as String,
      creatorID: data['creatorID'] as String,
      managerCount: data['managerCount'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'householdName': householdName,
    'creatorID': creatorID,
    if (managerCount != null) 'managerCount': managerCount,
  };
}

class HouseholdMember {
  final String userID; // matches the signed-in user's UID
  final String householdID;
  final String memberRole;
  final String displayName;

  // Avatar customization:
  final String? avatarSymbol;
  final int? avatarColor;

  const HouseholdMember({
    required this.userID,
    required this.householdID,
    required this.memberRole,
    this.displayName = '',
    this.avatarSymbol,
    this.avatarColor,
  });

  bool get isManager => memberRole == 'manager';
  bool get isMember => memberRole == 'member';
  bool get isChild => memberRole == 'child';

  factory HouseholdMember.fromMap(Map<String, dynamic> data) {
    return HouseholdMember(
      userID: data['userID'] as String? ?? '',
      householdID: data['householdID'] as String? ?? '',
      memberRole: data['memberRole'] as String? ?? 'member',
      displayName: data['displayName'] as String? ?? '',
      avatarSymbol: data['avatarSymbol'] as String?,
      avatarColor: data['avatarColor'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userID': userID,
    'householdID': householdID,
    'memberRole': memberRole,
    'displayName': displayName,
    if (avatarSymbol != null) 'avatarSymbol': avatarSymbol,
    if (avatarColor != null) 'avatarColor': avatarColor,
  };
}

class DisplayMember {
  final UserProfile profile;
  final HouseholdMember membership;

  const DisplayMember({required this.profile, required this.membership});

  String get initial => profile.displayName.isNotEmpty
      ? profile.displayName[0].toUpperCase()
      : '?';
}

class HouseholdTask {
  final String taskId;
  final String taskName;
  final String taskDescription; // may be empty
  final String taskStatus; // "pending" | "completed"
  final String createdByMemberID;
  final String? completedByMemberID;
  final DateTime? taskCompletionTime;

  // An empty list means that the task is assigned to Anyone
  final List<String> taskAssignedMemberIDs;

  const HouseholdTask({
    required this.taskId,
    required this.taskName,
    this.taskDescription = '',
    required this.taskStatus,
    required this.createdByMemberID,
    this.completedByMemberID,
    this.taskCompletionTime,
    this.taskAssignedMemberIDs = const [],
  });

  bool get isCompleted => taskStatus == 'completed';

  bool get isAssignedToAnyone => taskAssignedMemberIDs.isEmpty;

  bool isAssignedTo(String memberID) {
    return taskAssignedMemberIDs.contains(memberID);
  }

  // Call these helpers only for a verified household member
  bool canView({required String memberID, required String memberRole}) {
    return isAssignedToAnyone ||
        createdByMemberID == memberID ||
        isAssignedTo(memberID) ||
        memberRole == 'manager';
  }

  bool canComplete(String memberID) {
    return !isCompleted && (isAssignedToAnyone || isAssignedTo(memberID));
  }

  bool canChangeAssignees(String memberID) {
    return createdByMemberID == memberID;
  }

  HouseholdTask copyWith({
    String? taskName,
    String? taskDescription,
    String? taskStatus,
    String? completedByMemberID,
    DateTime? taskCompletionTime,
    List<String>? taskAssignedMemberIDs,
    bool clearCompletion = false,
  }) {
    return HouseholdTask(
      taskId: taskId,
      taskName: taskName ?? this.taskName,
      taskDescription: taskDescription ?? this.taskDescription,
      taskStatus: taskStatus ?? this.taskStatus,
      createdByMemberID: createdByMemberID,
      completedByMemberID: clearCompletion
          ? null
          : (completedByMemberID ?? this.completedByMemberID),
      taskCompletionTime: clearCompletion
          ? null
          : (taskCompletionTime ?? this.taskCompletionTime),
      taskAssignedMemberIDs: List<String>.unmodifiable(
        taskAssignedMemberIDs ?? this.taskAssignedMemberIDs,
      ),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'taskName': taskName,
    'taskDescription': taskDescription,
    'taskStatus': 'pending',
    'createdByMemberID': createdByMemberID,
    'completedByMemberID': null,
    'taskCompletionTime': null,
    'taskAssignedMemberIDs': List<String>.from(taskAssignedMemberIDs),
  };

  factory HouseholdTask.fromMap(String taskId, Map<String, dynamic> data) {
    final completionTime = data['taskCompletionTime'];

    return HouseholdTask(
      taskId: taskId,
      taskName: data['taskName'] as String? ?? '',
      taskDescription: data['taskDescription'] as String? ?? '',
      taskStatus: data['taskStatus'] as String? ?? 'pending',
      createdByMemberID: data['createdByMemberID'] as String? ?? '',
      completedByMemberID: data['completedByMemberID'] as String?,
      taskCompletionTime: completionTime is Timestamp
          ? completionTime.toDate()
          : null,
      taskAssignedMemberIDs: List<String>.unmodifiable(
        List<String>.from(data['taskAssignedMemberIDs'] as List? ?? const []),
      ),
    );
  }
}

// List of food item types:
const List<String> pantryFoodTypes = [
  'Nuts/Seeds',
  'Pasta',
  'Bread',
  'Canned/Jarred',
  'Snack',
  'Cereal',
  'Condiment',
  'Spice/Seasoning',
  'Fruit',
  'Vegetable',
  'Dairy',
  'Meat',
  'Frozen',
  'Beverage',
  'Other',
];

const String pantryInStock = 'inStock';
const String pantryOutOfStock = 'outOfStock';

// Pantry feature data:
class PantryItem {
  final String foodItemID;
  final String foodName;
  final String foodType;
  final int foodQuantity;
  final String foodStockStatus;
  final String foodDescription;

  const PantryItem({
    required this.foodItemID,
    required this.foodName,
    required this.foodType,
    required this.foodQuantity,
    required this.foodStockStatus,
    this.foodDescription = '',
  });

  bool get isInStock => foodQuantity > 0;

  String get displayStockStatus => isInStock ? 'In Stock' : 'Out of Stock';

  String get displayQuantity => foodQuantity > 99 ? '99+' : '$foodQuantity';

  static String stockStatusForQuantity(int quantity) {
    return quantity > 0 ? pantryInStock : pantryOutOfStock;
  }

  factory PantryItem.fromMap(String foodItemID, Map<String, dynamic> data) {
    final quantity = data['foodQuantity'] as int? ?? 0;

    return PantryItem(
      foodItemID: foodItemID,
      foodName: data['foodName'] as String? ?? '',
      foodType: data['foodType'] as String? ?? 'Other',
      foodQuantity: quantity,
      foodStockStatus: stockStatusForQuantity(quantity),
      foodDescription: data['foodDescription'] as String? ?? '',
    );
  }

  PantryItem copyWith({
    String? foodName,
    String? foodType,
    int? foodQuantity,
    String? foodDescription,
  }) {
    final newQuantity = foodQuantity ?? this.foodQuantity;

    return PantryItem(
      foodItemID: foodItemID,
      foodName: foodName ?? this.foodName,
      foodType: foodType ?? this.foodType,
      foodQuantity: newQuantity,
      foodStockStatus: stockStatusForQuantity(newQuantity),
      foodDescription: foodDescription ?? this.foodDescription,
    );
  }

  Map<String, dynamic> toMap() => {
    'foodName': foodName,
    'foodType': foodType,
    'foodQuantity': foodQuantity,
    'foodStockStatus': stockStatusForQuantity(foodQuantity),
    'foodDescription': foodDescription,
  };
}

class LowStockItem {
  final String name;
  final String category;

  const LowStockItem({required this.name, required this.category});
}

class StuffItem {
  final String itemId;
  final String itemName;
  final String itemDescription; // optional, may be empty
  final String itemStatus; // 'available' | 'low' | 'out_of_stock'
  final String listType; // 'household' | 'private'
  final String
  ownerMemberID; // whose private list it's on (ignored for household items)

  const StuffItem({
    required this.itemId,
    required this.itemName,
    this.itemDescription = '',
    this.itemStatus = 'available',
    required this.listType,
    required this.ownerMemberID,
  });

  bool get isPrivate => listType == 'private';

  bool get isOutOfStock => itemStatus == 'out_of_stock';

  factory StuffItem.fromMap(String itemId, Map<String, dynamic> data) {
    return StuffItem(
      itemId: itemId,
      itemName: data['itemName'] as String? ?? '',
      itemDescription: data['itemDescription'] as String? ?? '',
      itemStatus: data['itemStatus'] as String? ?? 'available',
      listType: data['listType'] as String,
      ownerMemberID: data['ownerMemberID'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'itemName': itemName,
    'itemDescription': itemDescription,
    'itemStatus': itemStatus,
    'listType': listType,
    'ownerMemberID': ownerMemberID,
  };

  StuffItem copyWith({
    String? itemName,
    String? itemDescription,
    String? itemStatus,
  }) {
    return StuffItem(
      itemId: itemId,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      itemStatus: itemStatus ?? this.itemStatus,
      listType: listType,
      ownerMemberID: ownerMemberID,
    );
  }
}

// Grocery List model:
const groceryListIncomplete = 'incomplete';
const groceryListComplete = 'complete';
const groceryListDefaultComplete = 'defaultComplete';
const groceryListCompleteNoReset = 'completeNoReset';

class GroceryList {
  final String groceryListID;
  final String groceryListName;
  final String groceryListStatus;
  final String groceryListDescription;
  final String groceryListVisibility;
  final String? ownerMemberID;
  final List<String> visibleMemberIDs;
  final int groceryItemsRevision;

  const GroceryList({
    required this.groceryListID,
    required this.groceryListName,
    this.groceryListStatus = groceryListIncomplete,
    this.groceryListDescription = '',
    this.groceryListVisibility = 'restricted',
    this.ownerMemberID,
    this.visibleMemberIDs = const [],
    this.groceryItemsRevision = 0,
  });

  bool get isDefault => groceryListID == 'default';

  bool get isComplete => groceryListStatus != groceryListIncomplete;

  bool canView(String memberID) {
    return groceryListVisibility == 'shared' ||
        ownerMemberID == memberID ||
        visibleMemberIDs.contains(memberID);
  }

  factory GroceryList.fromMap(String id, Map<String, dynamic> data) {
    return GroceryList(
      groceryListID: id,
      groceryListName: data['groceryListName'] as String? ?? '',
      groceryListStatus:
          data['groceryListStatus'] as String? ?? groceryListIncomplete,
      groceryListDescription: data['groceryListDescription'] as String? ?? '',
      groceryListVisibility:
          data['groceryListVisibility'] as String? ?? 'restricted',
      ownerMemberID: data['ownerMemberID'] as String?,
      visibleMemberIDs: List<String>.from(
        data['visibleMemberIDs'] as List? ?? const [],
      ),
      groceryItemsRevision: data['groceryItemsRevision'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'groceryListName': groceryListName,
    'groceryListStatus': groceryListStatus,
    'groceryListDescription': groceryListDescription,
    'groceryListVisibility': groceryListVisibility,
    'ownerMemberID': ownerMemberID,
    'visibleMemberIDs': visibleMemberIDs,
    'groceryItemsRevision': groceryItemsRevision,
  };
}

// Grocery Item model:
const groceryItemUnpurchased = 'unpurchased';
const groceryItemPurchased = 'purchased';

class GroceryItem {
  final String groceryItemID;
  final String groceryItemName;
  final String groceryItemType;
  final int groceryItemQuantity;
  final int groceryItemPurchasedQuantity;
  final String groceryItemStatus;
  final String groceryItemDescription;
  final String? sourceFoodItemID;
  final String? sourceHouseholdItemID;

  const GroceryItem({
    required this.groceryItemID,
    required this.groceryItemName,
    required this.groceryItemType,
    this.groceryItemQuantity = 1,
    this.groceryItemPurchasedQuantity = 0,
    this.groceryItemStatus = groceryItemUnpurchased,
    this.groceryItemDescription = '',
    this.sourceFoodItemID,
    this.sourceHouseholdItemID,
  });

  bool get isPurchased => groceryItemStatus == groceryItemPurchased;

  bool get hasSource =>
      sourceFoodItemID != null || sourceHouseholdItemID != null;

  String get displayStatus => isPurchased ? 'Purchased' : 'Unpurchased';

  factory GroceryItem.fromMap(String id, Map<String, dynamic> data) {
    return GroceryItem(
      groceryItemID: id,
      groceryItemName: data['groceryItemName'] as String? ?? '',
      groceryItemType: data['groceryItemType'] as String? ?? 'Other',
      groceryItemQuantity: data['groceryItemQuantity'] as int? ?? 1,
      groceryItemPurchasedQuantity:
          data['groceryItemPurchasedQuantity'] as int? ?? 0,
      groceryItemStatus:
          data['groceryItemStatus'] as String? ?? groceryItemUnpurchased,
      groceryItemDescription: data['groceryItemDescription'] as String? ?? '',
      sourceFoodItemID: data['sourceFoodItemID'] as String?,
      sourceHouseholdItemID: data['sourceHouseholdItemID'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'groceryItemName': groceryItemName,
    'groceryItemType': groceryItemType,
    'groceryItemQuantity': groceryItemQuantity,
    'groceryItemPurchasedQuantity': groceryItemPurchasedQuantity,
    'groceryItemStatus': groceryItemStatus,
    'groceryItemDescription': groceryItemDescription,
    'sourceFoodItemID': sourceFoodItemID,
    'sourceHouseholdItemID': sourceHouseholdItemID,
  };
}

class ActivityEntry {
  final String text;
  final String time;
  final bool isRestock;

  const ActivityEntry({
    required this.text,
    required this.time,
    this.isRestock = false,
  });
}

class InboxMessage {
  final String messageId;
  final String subject;
  final String body;
  final String sentByMemberID;
  final List<String> sentToMemberIDs; // up to 8
  final DateTime sentAt;
  final bool isRead;
 
  const InboxMessage({
    required this.messageId,
    required this.subject,
    required this.body,
    required this.sentByMemberID,
    required this.sentToMemberIDs,
    required this.sentAt,
    this.isRead = false,
  });
 
  String get bodyPreview {
    final trimmed = body.trim();
    if (trimmed.length <= 50) return trimmed;
    return '${trimmed.substring(0, 50)}…';
  }
 
  InboxMessage copyWith({bool? isRead}) {
    return InboxMessage(
      messageId: messageId,
      subject: subject,
      body: body,
      sentByMemberID: sentByMemberID,
      sentToMemberIDs: sentToMemberIDs,
      sentAt: sentAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

