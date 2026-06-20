import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, manager, worker }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.admin: return 'admin';
      case UserRole.manager: return 'manager';
      case UserRole.worker: return 'worker';
    }
  }

  static UserRole fromString(String role) {
    switch (role) {
      case 'admin': return UserRole.admin;
      case 'manager': return UserRole.manager;
      default: return UserRole.worker;
    }
  }
}

class UserModel {
  final String uid;
  final String name;
  final String surname;
  final String email;
  final String phone;
  final UserRole role;
  final String? currentCompanyId;
  final int vacationDays;
  final bool activeStatus;
  final String? profileImageUrl;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime? birthDate; // ← NOVO

  const UserModel({
    required this.uid,
    required this.name,
    required this.surname,
    required this.email,
    required this.phone,
    required this.role,
    this.currentCompanyId,
    this.vacationDays = 20,
    this.activeStatus = true,
    this.profileImageUrl,
    this.fcmToken,
    required this.createdAt,
    this.birthDate, // ← NOVO
  });

  String get fullName => '$name $surname';

  String get initials {
    final n = name.isNotEmpty ? name[0] : '';
    final s = surname.isNotEmpty ? surname[0] : '';
    return '$n$s'.toUpperCase();
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isWorker => role == UserRole.worker;
  bool get canManageSchedule => isAdmin || isManager;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      surname: data['surname'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'worker'),
      currentCompanyId: data['current_company_id'],
      activeStatus: data['active_status'] ?? true,
      profileImageUrl: data['profile_image_url'],
      fcmToken: data['fcm_token'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      birthDate: data['birth_date'] != null
          ? (data['birth_date'] as Timestamp).toDate()
          : null, // ← NOVO
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'surname': surname,
      'email': email,
      'phone': phone,
      'role': role.value,
      'current_company_id': currentCompanyId,
      'vacation_days': vacationDays,
      'active_status': activeStatus,
      'profile_image_url': profileImageUrl,
      'fcm_token': fcmToken,
      'created_at': Timestamp.fromDate(createdAt),
      'birth_date': birthDate != null // ← NOVO
          ? Timestamp.fromDate(birthDate!)
          : null,
    };
  }

  UserModel copyWith({
    String? name,
    String? surname,
    String? email,
    String? phone,
    UserRole? role,
    String? currentCompanyId,
    int? vacationDays,
    bool? activeStatus,
    String? profileImageUrl,
    String? fcmToken,
    DateTime? birthDate,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      currentCompanyId: currentCompanyId ?? this.currentCompanyId,
      vacationDays: vacationDays ?? this.vacationDays,
      activeStatus: activeStatus ?? this.activeStatus,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}