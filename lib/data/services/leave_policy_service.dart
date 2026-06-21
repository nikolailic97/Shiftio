import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_policy_model.dart';

class LeavePolicyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── DOHVATI POLICY ───────────────────────────────────────────────────────────

  Future<LeavePolicyModel> getPolicy(String companyId) async {
    final doc = await _db.collection('leave_policies').doc(companyId).get();

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
  Future<Map<String, int>> getWorkerUsedDays({
    required String userId,
    required String companyId,
    required int year,
  }) async {
    final policy = await getPolicy(companyId);
    final period = policy.currentPeriod(DateTime(year, 6, 15));

    return _getUsedDaysForPeriod(
      userId: userId,
      companyId: companyId,
      from: period.start,
      to: period.end,
    );
  }

  /// Iskorišćeni dani po tipu za TAČNO određen period [from, to).
  Future<Map<String, int>> _getUsedDaysForPeriod({
    required String userId,
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('requests')
        .where('user_id', isEqualTo: userId)
        .where('company_id', isEqualTo: companyId)
        .where('status', isEqualTo: 'approved')
        .get();

    final Map<String, int> used = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = data['type'] as String? ?? 'vacation';
      final start = (data['start_date'] as Timestamp).toDate();
      final requestedDays = data['requested_days'] as int? ?? 0;

      if (!start.isBefore(from) && start.isBefore(to)) {
        used[type] = (used[type] ?? 0) + requestedDays;
      }
    }
    return used;
  }

  /// Preostali dani po tipu za radnika u tekućem obračunskom periodu
  Future<Map<String, int>> getWorkerRemainingDays({
    required String userId,
    required String companyId,
    required int year,
  }) async {
    final policy = await getPolicy(companyId);
    final used = await getWorkerUsedDays(
      userId: userId,
      companyId: companyId,
      year: year,
    );

    final Map<String, int> remaining = {};
    for (final type in policy.leaveTypes) {
      final usedDays = used[type.id] ?? 0;
      remaining[type.id] =
          (type.daysPerYear - usedDays).clamp(0, type.daysPerYear);
    }
    return remaining;
  }
}
