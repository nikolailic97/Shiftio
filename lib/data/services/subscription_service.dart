import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shiftio/data/models/subscription_model.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int gracePeriodDays = 7;

  // ─── DOHVATI PRETPLATU ────────────────────────────────────────────────────────

  Stream<SubscriptionModel?> watchSubscription(String companyId) {
    return _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return SubscriptionModel.fromFirestore(snap.docs.first);
    });
  }

  Future<SubscriptionModel?> getSubscription(String companyId) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return SubscriptionModel.fromFirestore(snap.docs.first);
  }

  // ─── KREIRAJ FREE TIER (za novu firmu) ───────────────────────────────────────

  Future<void> createFreeTier(String companyId) async {
    final existing = await getSubscription(companyId);
    if (existing != null) return;

    final docRef = _db.collection('subscriptions').doc();
    final sub = SubscriptionModel.freeTier(companyId);
    await docRef.set({...sub.toFirestore(), 'subscription_id': docRef.id});
  }

  // ─── PROVJERA LIMITA ──────────────────────────────────────────────────────────

  /// Može li admin dodati novog radnika
  Future<LimitCheckResult> canAddWorker(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;

    final workersSnap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('active_status', isEqualTo: true)
        .get();

    final currentCount = workersSnap.size;
    final maxAllowed = tier.maxWorkers;

    if (currentCount >= maxAllowed) {
      return LimitCheckResult(
        allowed: false,
        currentCount: currentCount,
        maxCount: maxAllowed,
        tier: tier,
        message:
            'Dostigli ste limit od $maxAllowed radnika za ${tier.label} plan.',
      );
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: currentCount,
      maxCount: maxAllowed,
      tier: tier,
    );
  }

  /// Može li admin slati notifikacije
  Future<LimitCheckResult> canSendNotification(String companyId) async {
    final sub = await getSubscription(companyId);
    if (sub == null) {
      return LimitCheckResult(
        allowed: false,
        currentCount: 0,
        maxCount: 0,
        tier: SubscriptionTier.free,
        message: 'Pretplata nije pronađena.',
      );
    }

    final tier = sub.effectiveTier;
    final remaining = sub.remainingDailyNotifications;

    if (remaining <= 0) {
      return LimitCheckResult(
        allowed: false,
        currentCount: sub.dailyNotificationCount,
        maxCount: tier.maxDailyNotifications,
        tier: tier,
        message:
            'Dostigli ste dnevni limit od ${tier.maxDailyNotifications} notifikacija.',
      );
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: sub.dailyNotificationCount,
      maxCount: tier.maxDailyNotifications,
      tier: tier,
    );
  }

  /// Može li admin kreirati novu smenu (Soft Lock provjera)
  Future<LimitCheckResult> canCreateShift(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;

    // Soft Lock: ako je expired i ima više radnika nego što Free dozvoljava
    if (sub != null && sub.isExpired) {
      final workersSnap = await _db
          .collection('users')
          .where('current_company_id', isEqualTo: companyId)
          .where('active_status', isEqualTo: true)
          .get();

      if (workersSnap.size > SubscriptionTier.free.maxWorkers) {
        return LimitCheckResult(
          allowed: false,
          currentCount: workersSnap.size,
          maxCount: SubscriptionTier.free.maxWorkers,
          tier: tier,
          isSoftLocked: true,
          message:
              'Planer je zaključan. Obnovi pretplatu ili ukloni radnike na limit Free plana (${SubscriptionTier.free.maxWorkers}).',
        );
      }
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: 0,
      maxCount: 0,
      tier: tier,
    );
  }

  /// Može li admin exportovati podatke
  Future<LimitCheckResult> canExport(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;

    if (!tier.canExport) {
      return LimitCheckResult(
        allowed: false,
        currentCount: 0,
        maxCount: 0,
        tier: tier,
        message: 'Export podataka nije dostupan na Free planu.',
      );
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: 0,
      maxCount: 0,
      tier: tier,
    );
  }

  // ─── POVEĆAJ BROJ NOTIFIKACIJA ────────────────────────────────────────────────

  Future<void> incrementNotificationCount(String companyId, int count) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    await snap.docs.first.reference.update({
      'daily_notification_count': FieldValue.increment(count),
    });
  }

  // ─── SOFT LOCK — zaključaj poslednjeg radnika ─────────────────────────────────

  /// Kada pretplata istekne i firma ima više radnika od Free limita,
  /// poslednji dodani radnik se zaključava
  Future<void> applyWorkerSoftLock(String companyId) async {
    final workersSnap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('active_status', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();

    final maxWorkers = SubscriptionTier.free.maxWorkers;
    if (workersSnap.size <= maxWorkers) return;

    // Zaključaj poslednje dodane radnike koji su preko limita
    final toBlock = workersSnap.docs.take(workersSnap.size - maxWorkers);
    final batch = _db.batch();
    for (final doc in toBlock) {
      batch.update(doc.reference, {'soft_locked': true});
    }
    await batch.commit();
  }

  // ─── GRACE PERIOD ─────────────────────────────────────────────────────────────

  Future<void> startGracePeriod(String companyId) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final gracePeriodEnd =
        DateTime.now().add(const Duration(days: gracePeriodDays));

    await snap.docs.first.reference.update({
      'status': SubscriptionStatus.gracePeriod.value,
      'grace_period_end': Timestamp.fromDate(gracePeriodEnd),
    });
  }

  Future<void> expireSubscription(String companyId) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    await snap.docs.first.reference.update({
      'status': SubscriptionStatus.expired.value,
      'tier': SubscriptionTier.free.value,
    });

    // Primijeni Soft Lock
    await applyWorkerSoftLock(companyId);
  }

  // ─── OBNOVI PRETPLATU (simulacija — RevenueCat webhook) ──────────────────────

  Future<void> renewSubscription({
    required String companyId,
    required SubscriptionTier tier,
    required SubscriptionCycle cycle,
  }) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    final endDate = cycle == SubscriptionCycle.monthly
        ? DateTime.now().add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 365));

    final data = {
      'tier': tier.value,
      'status': SubscriptionStatus.active.value,
      'cycle': cycle.value,
      'end_date': Timestamp.fromDate(endDate),
      'grace_period_end': null,
    };

    if (snap.docs.isEmpty) {
      final docRef = _db.collection('subscriptions').doc();
      await docRef.set({
        'company_id': companyId,
        'daily_notification_count': 0,
        'created_at': Timestamp.fromDate(DateTime.now()),
        ...data,
      });
    } else {
      await snap.docs.first.reference.update(data);
    }

    // Otključaj soft-locked radnike
    await _unlockWorkers(companyId, tier.maxWorkers);
  }

  Future<void> _unlockWorkers(String companyId, int maxWorkers) async {
    final snap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('soft_locked', isEqualTo: true)
        .get();

    final batch = _db.batch();
    int unlocked = 0;
    for (final doc in snap.docs) {
      if (unlocked < maxWorkers) {
        batch.update(doc.reference, {'soft_locked': false});
        unlocked++;
      }
    }
    await batch.commit();
  }
}

// ─── Rezultat provjere limita ─────────────────────────────────────────────────
class LimitCheckResult {
  final bool allowed;
  final int currentCount;
  final int maxCount;
  final SubscriptionTier tier;
  final bool isSoftLocked;
  final String? message;

  const LimitCheckResult({
    required this.allowed,
    required this.currentCount,
    required this.maxCount,
    required this.tier,
    this.isSoftLocked = false,
    this.message,
  });
}
