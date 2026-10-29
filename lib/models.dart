import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String email;
  final String displayName;
  final String? householdID;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    required this.displayName,
    this.householdID,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      householdID: data['householdID'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'username': username,
    'email': email,
    'displayName': displayName,
    if (householdID != null) 'householdID': householdID,
  };
}

class Household {
  final String householdID;
  final String householdName;
  final String creatorID;

  const Household({
    required this.householdID,
    required this.householdName,
    required this.creatorID,
  });

  factory Household.fromMap(String householdID, Map<String, dynamic> data) {
    return Household(
      householdID: householdID,
      householdName: data['householdName'] as String,
      creatorID: data['creatorID'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'householdName': householdName, 'creatorID': creatorID};
  }
}

class HouseholdMember {
  final String userID; // matches the signed-in user's UID
  final String householdID;
  final String memberRole;
  final String displayName;

  const HouseholdMember({
    required this.userID,
    required this.householdID,
    required this.memberRole,
    this.displayName = '',
  });

  factory HouseholdMember.fromMap(Map<String, dynamic> data) {
    return HouseholdMember(
      userID: data['userID'] as String? ?? '',
      householdID: data['householdID'] as String? ?? '',
      memberRole: data['memberRole'] as String? ?? 'member',
      displayName: data['displayName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'userID': userID,
    'householdID': householdID,
    'memberRole': memberRole,
    'displayName': displayName,
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
  final String ownerMemberID; // whose private list it's on (ignored for household items)

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

  factory StuffItem.fromMap(
    String itemId,
    Map<String, dynamic> data,
  ) {
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
