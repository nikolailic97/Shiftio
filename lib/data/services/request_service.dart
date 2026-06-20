import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../models/support_ticket_model.dart';

class RequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── REQUESTS ─────────────────────────────────────────────────────────────────

  /// Stream zahteva za firmu (Admin/Manager pogled)
  Stream<List<RequestModel>> watchCompanyRequests(String companyId) {
    return _db
        .collection('requests')
        .where('company_id', isEqualTo: companyId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RequestModel.fromFirestore(d)).toList());
  }

  /// Stream zahteva za radnika (Worker pogled)
  Stream<List<RequestModel>> watchWorkerRequests(String userId) {
    return _db
        .collection('requests')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RequestModel.fromFirestore(d)).toList());
  }

  /// Broj pending zahteva (za badge)
  Stream<int> watchPendingCount(String companyId) {
    return _db
        .collection('requests')
        .where('company_id', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Kreiraj zahtev za godišnji odmor
  Future<void> createVacationRequest({
    required String userId,
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;

    final docRef = _db.collection('requests').doc();
    final request = RequestModel(
      requestId: docRef.id,
      userId: userId,
      companyId: companyId,
      type: RequestType.vacation,
      startDate: startDate,
      endDate: endDate,
      status: RequestStatus.pending,
      reason: reason,
      createdAt: DateTime.now(),
      requestedDays: days,
    );

    await docRef.set(request.toFirestore());
  }

  /// Pošalji zahtjev za bolovanje (admin mora odobriti)
  Future<void> startSickLeave({
    required String userId,
    required String companyId,
  }) async {
    final docRef = _db.collection('requests').doc();
    final request = RequestModel(
      requestId: docRef.id,
      userId: userId,
      companyId: companyId,
      type: RequestType.sick,
      startDate: DateTime.now(),
      status: RequestStatus.pending, // ← pending, ne auto-approved
      createdAt: DateTime.now(),
    );

    await docRef.set(request.toFirestore());
  }

  /// Admin završava bolovanje — postavi end_date
  Future<void> endSickLeave(String requestId) async {
    await _db.collection('requests').doc(requestId).update({
      'end_date': Timestamp.fromDate(DateTime.now()),
      'status': RequestStatus.completed.value,
    });
  }

  Future<void> approveRequest({
    required String requestId,
    required String reviewedBy,
  }) async {
    await _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.approved.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Admin odbija zahtev sa napomenom
  Future<void> rejectRequest({
    required String requestId,
    required String reviewedBy,
    String? rejectNote,
  }) async {
    await _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.rejected.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': Timestamp.fromDate(DateTime.now()),
      'reject_note': rejectNote,
    });
  }

  /// Radnik otkazuje pending zahtev
  Future<void> cancelRequest(String requestId) async {
    await _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.cancelled.value,
    });
  }

  // ─── SUPPORT ──────────────────────────────────────────────────────────────────

  Future<void> sendSupportTicket({
    required String userId,
    required String message,
  }) async {
    final docRef = _db.collection('support_tickets').doc();
    final ticket = SupportTicketModel(
      ticketId: docRef.id,
      userId: userId,
      message: message,
      timestamp: DateTime.now(),
    );

    await docRef.set(ticket.toFirestore());
  }

  // ─── ACTIVE SICK LEAVE ────────────────────────────────────────────────────────

  /// Provjeri da li radnik ima aktivno ili pending bolovanje
  Future<RequestModel?> getActiveSickLeave(String userId) async {
    final snap = await _db
        .collection('requests')
        .where('user_id', isEqualTo: userId)
        .where('type', isEqualTo: 'sick')
        .where('status', whereIn: ['approved', 'pending'])
        .where('end_date', isNull: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return RequestModel.fromFirestore(snap.docs.first);
  }
}
