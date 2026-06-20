import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestType { vacation, sick }
enum RequestStatus { pending, approved, rejected, cancelled, completed }

extension RequestTypeExt on RequestType {
  String get value => this == RequestType.vacation ? 'vacation' : 'sick';
  String get label => this == RequestType.vacation ? 'Godišnji odmor' : 'Bolovanje';

  static RequestType fromString(String s) =>
      s == 'vacation' ? RequestType.vacation : RequestType.sick;
}

extension RequestStatusExt on RequestStatus {
  String get value {
    switch (this) {
      case RequestStatus.pending: return 'pending';
      case RequestStatus.approved: return 'approved';
      case RequestStatus.rejected: return 'rejected';
      case RequestStatus.cancelled: return 'cancelled';
      case RequestStatus.completed: return 'completed';
    }
  }

  String get label {
    switch (this) {
      case RequestStatus.pending: return 'Na čekanju';
      case RequestStatus.approved: return 'Odobreno';
      case RequestStatus.rejected: return 'Odbijeno';
      case RequestStatus.cancelled: return 'Otkazano';
      case RequestStatus.completed: return 'Završeno';
    }
  }

  static RequestStatus fromString(String s) {
    switch (s) {
      case 'approved': return RequestStatus.approved;
      case 'rejected': return RequestStatus.rejected;
      case 'cancelled': return RequestStatus.cancelled;
      case 'completed': return RequestStatus.completed;
      default: return RequestStatus.pending;
    }
  }
}

class RequestModel {
  final String requestId;
  final String userId;
  final String companyId;
  final RequestType type;
  final DateTime startDate;
  final DateTime? endDate;
  final RequestStatus status;
  final String? reason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final int? requestedDays;
  final String? rejectNote;

  const RequestModel({
    required this.requestId,
    required this.userId,
    required this.companyId,
    required this.type,
    required this.startDate,
    this.endDate,
    required this.status,
    this.reason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    this.requestedDays,
    this.rejectNote,
  });

  bool get isSick => type == RequestType.sick;
  bool get isVacation => type == RequestType.vacation;
  bool get isPending => status == RequestStatus.pending;

  factory RequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RequestModel(
      requestId: doc.id,
      userId: data['user_id'] ?? '',
      companyId: data['company_id'] ?? '',
      type: RequestTypeExt.fromString(data['type'] ?? 'vacation'),
      startDate: (data['start_date'] as Timestamp).toDate(),
      endDate: data['end_date'] != null
          ? (data['end_date'] as Timestamp).toDate()
          : null,
      status: RequestStatusExt.fromString(data['status'] ?? 'pending'),
      reason: data['reason'],
      reviewedBy: data['reviewed_by'],
      reviewedAt: data['reviewed_at'] != null
          ? (data['reviewed_at'] as Timestamp).toDate()
          : null,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestedDays: data['requested_days'],
      rejectNote: data['reject_note'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'company_id': companyId,
      'type': type.value,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status.value,
      'reason': reason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'requested_days': requestedDays,
      'reject_note': rejectNote,
    };
  }
}