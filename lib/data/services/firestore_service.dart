import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── COMPANY ─────────────────────────────────────────────────────────────────

  Future<CompanyModel?> getCompany(String companyId) async {
    final doc = await _db.collection('companies').doc(companyId).get();
    if (!doc.exists) return null;
    return CompanyModel.fromFirestore(doc);
  }

  Stream<CompanyModel?> watchCompany(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists ? CompanyModel.fromFirestore(doc) : null);
  }

  Future<void> updateCompanyName(String companyId, String name) async {
    await _db.collection('companies').doc(companyId).update({'name': name});
  }

  // ─── USERS / TEAM ─────────────────────────────────────────────────────────────

  Stream<List<UserModel>> watchTeamMembers(String companyId) {
    return _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('active_status', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Future<List<UserModel>> getTeamMembers(String companyId) async {
    final snap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('active_status', isEqualTo: true)
        .get();
    return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Dodeli manager ulogu radniku (samo admin)
  Future<void> setUserRole(String uid, UserRole role) async {
    await _db.collection('users').doc(uid).update({'role': role.value});
  }

  /// Ukloni radnika iz firme (deaktiviraj)
  Future<void> removeWorker(String uid) async {
    await _db.collection('users').doc(uid).update({
      'active_status': false,
      'current_company_id': null,
    });
  }

  /// Ažuriraj FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcm_token': token});
  }

  // ─── SHIFTS ──────────────────────────────────────────────────────────────────

  /// Stream smena za određeni dan i firmu (Admin/Manager pogled)
  Stream<List<ShiftModel>> watchShiftsForDate({
    required String companyId,
    required DateTime date,
  }) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _db
        .collection('shifts')
        .where('company_id', isEqualTo: companyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .orderBy('start_time')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList());
  }

  /// Stream smena za određenog radnika (Worker pogled)
  Stream<List<ShiftModel>> watchWorkerShiftsForDate({
    required String workerId,
    required DateTime date,
  }) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _db
        .collection('shifts')
        .where('worker_id', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .orderBy('start_time')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList());
  }

  /// Stream svih smena firme za mjesec (za admin calendar dots)
  Stream<List<ShiftModel>> watchCompanyShiftsForWeek({
    required String companyId,
    required DateTime weekStart,
  }) {
    // Pratimo cijeli mjesec za calendar dots
    final monthStart = DateTime(weekStart.year, weekStart.month, 1);
    final monthEnd = DateTime(weekStart.year, weekStart.month + 1, 1);

    return _db
        .collection('shifts')
        .where('company_id', isEqualTo: companyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThan: Timestamp.fromDate(monthEnd))
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList());
  }

  /// Stream svih smena radnika za mjesec (za worker calendar dots)
  Stream<List<ShiftModel>> watchWorkerShiftsForWeek({
    required String workerId,
    required DateTime weekStart,
  }) {
    final monthStart = DateTime(weekStart.year, weekStart.month, 1);
    final monthEnd = DateTime(weekStart.year, weekStart.month + 1, 1);

    return _db
        .collection('shifts')
        .where('worker_id', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThan: Timestamp.fromDate(monthEnd))
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList());
  }

  /// Kreiraj jednu smenu
  Future<void> createShift(ShiftModel shift) async {
    final docRef = _db.collection('shifts').doc();
    await docRef.set(shift.toFirestore());
  }

  /// Kreiraj smene za više radnika odjednom (optimizovani batch)
  Future<void> createShiftsBatch({
    required String companyId,
    required List<String> workerIds,
    required DateTime startTime,
    required int durationMinutes,
    required DateTime date,
    String? noteAdmin,
    bool sendNotification = false,
  }) async {
    final batchId = _uuid.v4();
    
    // Firestore batch max 500 — splitujemo ako treba
    const maxBatchSize = 400;
    final chunks = <List<String>>[];
    
    for (int i = 0; i < workerIds.length; i += maxBatchSize) {
      chunks.add(workerIds.sublist(
        i,
        i + maxBatchSize > workerIds.length ? workerIds.length : i + maxBatchSize,
      ));
    }

    for (final chunk in chunks) {
      final batch = _db.batch();
      for (final workerId in chunk) {
        final docRef = _db.collection('shifts').doc();
        final shift = ShiftModel(
          shiftId: docRef.id,
          companyId: companyId,
          workerId: workerId,
          batchId: batchId,
          startTime: startTime,
          durationMinutes: durationMinutes,
          date: date,
          noteAdmin: noteAdmin,
          timestamp: DateTime.now(),
          notificationSent: sendNotification,
        );
        batch.set(docRef, shift.toFirestore());
      }
      await batch.commit();
    }
  }

  /// Dodaj komentar radnika na smenu
  Future<void> addWorkerComment(String shiftId, String comment) async {
    await _db.collection('shifts').doc(shiftId).update({
      'worker_comment': comment,
      'has_comment': comment.isNotEmpty,
    });
  }

  /// Izmeni smenu
  Future<void> updateShift(String shiftId, Map<String, dynamic> data) async {
    await _db.collection('shifts').doc(shiftId).update(data);
  }

  /// Obriši jednu smenu
  Future<void> deleteShift(String shiftId) async {
    await _db.collection('shifts').doc(shiftId).delete();
  }

  /// Obriši sve smene iz batch-a
  Future<void> deleteShiftsBatch(String batchId) async {
    final snap = await _db
        .collection('shifts')
        .where('batch_id', isEqualTo: batchId)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ─── STATISTICS ──────────────────────────────────────────────────────────────

  /// Ukupni sati radnika za dati period
  Future<int> getTotalMinutesForWorker({
    required String workerId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('shifts')
        .where('worker_id', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .get();

    final shifts =
        snap.docs.map((doc) => ShiftModel.fromFirestore(doc)).toList();
    return shifts.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }
}