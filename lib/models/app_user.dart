import 'package:cloud_firestore/cloud_firestore.dart';

class IncentiveItem {
  final String label;
  final int value;

  IncentiveItem({
    required this.label,
    required this.value,
  });

  factory IncentiveItem.fromMap(Map<String, dynamic> map) {
    return IncentiveItem(
      label: map['label'] ?? '',
      value: map['value'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'value': value,
    };
  }

  IncentiveItem copyWith({
    String? label,
    int? value,
  }) {
    return IncentiveItem(
      label: label ?? this.label,
      value: value ?? this.value,
    );
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final List<IncentiveItem> incentives;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.incentives,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<IncentiveItem> incentivesList = [];
    if (data['incentives'] != null) {
      incentivesList = (data['incentives'] as List)
          .map((item) => IncentiveItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return AppUser(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      incentives: incentivesList,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    List<IncentiveItem> incentivesList = [];
    if (map['incentives'] != null) {
      incentivesList = (map['incentives'] as List)
          .map((item) => IncentiveItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      incentives: incentivesList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'incentives': incentives.map((item) => item.toMap()).toList(),
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    List<IncentiveItem>? incentives,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      incentives: incentives ?? this.incentives,
    );
  }

  // Helper getters
  int get totalIncentives {
    return incentives.fold(0, (sum, item) => sum + item.value);
  }

  // Role helpers
  bool get isSuperAdmin => role.toLowerCase() == 'superadmin';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isInstallation => role.toLowerCase() == 'installation';
  bool get isSurvey => role.toLowerCase() == 'survey';
  bool get isSales => role.toLowerCase() == 'sales';
  bool get isOperations => role.toLowerCase() == 'operation';
  
  // Check if user has admin privileges (superadmin or admin)
  bool get hasAdminPrivileges => isSuperAdmin || isAdmin;
}