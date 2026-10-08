
class UserProfile {
  final String uid; 
  final String username;
  final String email;
  final String displayName;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    required this.displayName,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'displayName': displayName,
      };
}


class HouseholdMember {
  final String userID; // matches the signed-in user's UID
  final String householdID;
  final String memberRole; 

  const HouseholdMember({
    required this.userID,
    required this.householdID,
    required this.memberRole,
  });

  factory HouseholdMember.fromMap(Map<String, dynamic> data) {
    return HouseholdMember(
      userID: data['userID'] as String? ?? '',
      householdID: data['householdID'] as String? ?? '',
      memberRole: data['memberRole'] as String? ?? 'member',
    );
  }

  Map<String, dynamic> toMap() => {
        'userID': userID,
        'householdID': householdID,
        'memberRole': memberRole,
      };
}


class DisplayMember {
  final UserProfile profile;
  final HouseholdMember membership;

  const DisplayMember({required this.profile, required this.membership});

  String get initial =>
      profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?';
}


class HouseholdTask {
  final String taskId; 
  final String taskName; 
  final String taskDescription; // may be empty
  final String taskStatus; // "pending" | "completed"
  final String createdByMemberID;
  final String? completedByMemberID;
  final DateTime? taskCompletionTime;

  const HouseholdTask({
    required this.taskId,
    required this.taskName,
    this.taskDescription = '',
    required this.taskStatus,
    required this.createdByMemberID,
    this.completedByMemberID,
    this.taskCompletionTime,
  });

  bool get isCompleted => taskStatus == 'completed';

  
  HouseholdTask copyWith({
    String? taskStatus,
    String? completedByMemberID,
    DateTime? taskCompletionTime,
  }) {
    return HouseholdTask(
      taskId: taskId,
      taskName: taskName,
      taskDescription: taskDescription,
      taskStatus: taskStatus ?? this.taskStatus,
      createdByMemberID: createdByMemberID,
      completedByMemberID: completedByMemberID ?? this.completedByMemberID,
      taskCompletionTime: taskCompletionTime ?? this.taskCompletionTime,
    );
  }

  
  Map<String, dynamic> toCreateMap() => {
        'taskName': taskName,
        'taskDescription': taskDescription,
        'taskStatus': 'pending',
        'createdByMemberID': createdByMemberID,
      };

  
  static Map<String, dynamic> completeMap(String completedByMemberID) => {
        'taskStatus': 'completed',
        'completedByMemberID': completedByMemberID,
        
      };

  factory HouseholdTask.fromMap(String taskId, Map<String, dynamic> data) {
    return HouseholdTask(
      taskId: taskId,
      taskName: data['taskName'] as String? ?? '',
      taskDescription: data['taskDescription'] as String? ?? '',
      taskStatus: data['taskStatus'] as String? ?? 'pending',
      createdByMemberID: data['createdByMemberID'] as String? ?? '',
      completedByMemberID: data['completedByMemberID'] as String?,
      
    );
  }
}


class LowStockItem {
  final String name;
  final String category; 

  const LowStockItem({required this.name, required this.category});
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
