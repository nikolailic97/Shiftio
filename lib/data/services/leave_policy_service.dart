import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_policy_model.dart';

class LeavePolicyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── DOHVATI POLICY ───────────────────────────────────────────────────────────

  Future<LeavePolicyModel> getPolicy(String companyId) async {
    final doc = await _db
        .collection('leave_policies')
        .doc(companyId)
        .get();

    if (!doc.exists) {
      // Kreiraj default policy
      final defaultPolicy = LeavePolicyModel.defaultPolicy(companyId);
      await savePolicy(defaultPolicy);
      return defaultPolicy;
    }

    return LeavePolicyModel.fromFirestore(doc);
  }

  Stream<LeavePolicyModel> watchPolicy(String companyId) {
    return _db
        .collection('leave_policies')
        .doc(companyId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) {
        final defaultPolicy = LeavePolicyModel.defaultPolicy(companyId);
        await savePolicy(defaultPolicy);
        return defaultPolicy;
      }
      return LeavePolicyModel.fromFirestore(doc);
    });
  }

  // ─── SAČUVAJ POLICY ───────────────────────────────────────────────────────────

  Future<void> savePolicy(LeavePolicyModel policy) async {
    await _db
        .collection('leave_policies')
        .doc(policy.companyId)
        .set(policy.toFirestore());
  }

  // ─── WORKER BALANCE ───────────────────────────────────────────────────────────

  /// Dohvati iskorišćene dane po tipu za radnika u ovoj godini
  Future<Map<String, int>> getWorkerUsedDays({
    required String userId,
    required int year,
  }) async {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year + 1, 1, 1);

    final snap = await _db
        .collection('requests')
        .where('user_id', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();

    final Map<String, int> used = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final type = data['type'] as String? ?? 'vacation';
      final start = (data['start_date'] as Timestamp).toDate();
      final requestedDays = data['requested_days'] as int? ?? 0;

      if (!start.isBefore(yearStart) && start.isBefore(yearEnd)) {
        used[type] = (used[type] ?? 0) + requestedDays;
      }
    }

    return used;
  }

  /// Preostali dani po tipu za radnika
  Future<Map<String, int>> getWorkerRemainingDays({
    required String userId,
    required String companyId,
    required int year,
  }) async {
    final policy = await getPolicy(companyId);
    final used = await getWorkerUsedDays(userId: userId, year: year);

    final Map<String, int> remaining = {};
    for (final type in policy.leaveTypes) {
      final usedDays = used[type.id] ?? 0;
      remaining[type.id] = (type.daysPerYear - usedDays).clamp(0, type.daysPerYear);
    }
    return remaining;
  }
}