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

  /// Mesec i dan kada se kvota svih tipova odmora resetuje za celu firmu
  /// (npr. resetMonth=3, resetDay=1 → svake 1. marta). Podrazumevano
  /// 1. januar (kalendarska godina), dok admin ne postavi drugačije.
  final int resetMonth;
  final int resetDay;

  final DateTime updatedAt;

  const LeavePolicyModel({
    required this.companyId,
    required this.leaveTypes,
    this.resetMonth = 1,
    this.resetDay = 1,
    required this.updatedAt,
  });

  /// Datum reseta za zadatu godinu (npr. za year=2026 i resetMonth=3,
  /// resetDay=1 → 1. mart 2026).
  DateTime resetDateFor(int year) => DateTime(year, resetMonth, resetDay);

  /// Vraća granice tekućeg "obračunskog perioda" odmora za dati trenutak
  /// (podrazumevano sada). Ako je reset npr. 1. mart, a danas je 15.
  /// januar 2026, period je [1.3.2025 – 1.3.2026), jer poslednji reset
  /// još nije prošao ove kalendarske godine.
  ({DateTime start, DateTime end}) currentPeriod([DateTime? now]) {
    final today = now ?? DateTime.now();
    var periodStart = resetDateFor(today.year);

    if (today.isBefore(periodStart)) {
      // Reset ove godine još nije prošao — period je počeo prošle godine
      periodStart = resetDateFor(today.year - 1);
    }

    final periodEnd = DateTime(
      periodStart.year + 1,
      periodStart.month,
      periodStart.day,
    );

    return (start: periodStart, end: periodEnd);
  }

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
      resetMonth: 1,
      resetDay: 1,
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
      resetMonth: data['reset_month'] ?? 1,
      resetDay: data['reset_day'] ?? 1,
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'leave_types': leaveTypes.map((t) => t.toMap()).toList(),
      'reset_month': resetMonth,
      'reset_day': resetDay,
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

  LeavePolicyModel copyWith({
    List<LeaveType>? leaveTypes,
    int? resetMonth,
    int? resetDay,
  }) {
    return LeavePolicyModel(
      companyId: companyId,
      leaveTypes: leaveTypes ?? this.leaveTypes,
      resetMonth: resetMonth ?? this.resetMonth,
      resetDay: resetDay ?? this.resetDay,
      updatedAt: DateTime.now(),
    );
  }
}
