import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveType {
  final String id;
  final String name;
  final int daysPerYear;
  final bool carriesOver; // prenosi se u sljedeću godinu
  final bool requiresApproval;

  const LeaveType({
    required this.id,
    required this.name,
    required this.daysPerYear,
    this.carriesOver = false,
    this.requiresApproval = true,
  });

  factory LeaveType.fromMap(Map<String, dynamic> data) {
    return LeaveType(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      daysPerYear: data['days_per_year'] ?? 0,
      carriesOver: data['carries_over'] ?? false,
      requiresApproval: data['requires_approval'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'days_per_year': daysPerYear,
      'carries_over': carriesOver,
      'requires_approval': requiresApproval,
    };
  }

  LeaveType copyWith({
    String? name,
    int? daysPerYear,
    bool? carriesOver,
    bool? requiresApproval,
  }) {
    return LeaveType(
      id: id,
      name: name ?? this.name,
      daysPerYear: daysPerYear ?? this.daysPerYear,
      carriesOver: carriesOver ?? this.carriesOver,
      requiresApproval: requiresApproval ?? this.requiresApproval,
    );
  }
}

class LeavePolicyModel {
  final String companyId;
  final List<LeaveType> leaveTypes;
  final DateTime updatedAt;

  const LeavePolicyModel({
    required this.companyId,
    required this.leaveTypes,
    required this.updatedAt,
  });

  // Default policy za novu firmu
  factory LeavePolicyModel.defaultPolicy(String companyId) {
    return LeavePolicyModel(
      companyId: companyId,
      leaveTypes: [
        const LeaveType(
          id: 'vacation',
          name: 'Godišnji odmor',
          daysPerYear: 20,
          carriesOver: false,
          requiresApproval: true,
        ),
        const LeaveType(
          id: 'slava',
          name: 'Slava',
          daysPerYear: 1,
          carriesOver: false,
          requiresApproval: false,
        ),
        const LeaveType(
          id: 'sick',
          name: 'Bolovanje',
          daysPerYear: 5,
          carriesOver: false,
          requiresApproval: true,
        ),
      ],
      updatedAt: DateTime.now(),
    );
  }

  factory LeavePolicyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final types = (data['leave_types'] as List<dynamic>?)
            ?.map((t) => LeaveType.fromMap(t as Map<String, dynamic>))
            .toList() ??
        [];
    return LeavePolicyModel(
      companyId: data['company_id'] ?? '',
      leaveTypes: types,
      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'leave_types': leaveTypes.map((t) => t.toMap()).toList(),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  LeaveType? getType(String id) {
    try {
      return leaveTypes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}