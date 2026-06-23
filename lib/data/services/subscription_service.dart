import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── DOHVATI PRETPLATU ────────────────────────────────────────────────────

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

  // ─── KREIRAJ FREE TIER (za novu firmu) ───────────────────────────────────

  Future<void> createFreeTier(String companyId) async {
    final existing = await getSubscription(companyId);
    if (existing != null) return;

    final docRef = _db.collection('subscriptions').doc();
    final sub = SubscriptionModel.freeTier(companyId);
    await docRef.set({...sub.toFirestore(), 'subscription_id': docRef.id});
  }

  // ─── PROVJERA LIMITA ──────────────────────────────────────────────────────

  /// Može li admin dodati novog radnika (uzima u obzir seat addon-e)
  Future<LimitCheckResult> canAddWorker(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;
    final totalLimit = sub?.totalWorkerLimit ?? tier.baseWorkerLimit;

    final workersSnap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('active_status', isEqualTo: true)
        .get();

    final currentCount = workersSnap.size;

    if (currentCount >= totalLimit) {
      final canBuySeatAddons = tier.canUseSeatAddons;
      return LimitCheckResult(
        allowed: false,
        currentCount: currentCount,
        maxCount: totalLimit,
        tier: tier,
        requiresUpgrade: !canBuySeatAddons,
        requiresSeatAddon: canBuySeatAddons,
        message: canBuySeatAddons
            ? 'Dostigli ste limit od $totalLimit radnika. Kupite seat addon da dodate više.'
            : 'Dostigli ste limit od $totalLimit radnika za Free plan. Nadogradite na Standard.',
      );
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: currentCount,
      maxCount: totalLimit,
      tier: tier,
    );
  }

  /// Može li admin koristiti export
  Future<LimitCheckResult> canExport(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;

    if (!tier.canExport) {
      return LimitCheckResult(
        allowed: false,
        currentCount: 0,
        maxCount: 0,
        tier: tier,
        requiresUpgrade: true,
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

  /// Može li admin pristupiti Pro dashboard-u
  Future<LimitCheckResult> canUseDashboard(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;

    if (!tier.canUseDashboard) {
      return LimitCheckResult(
        allowed: false,
        currentCount: 0,
        maxCount: 0,
        tier: tier,
        requiresUpgrade: true,
        message: 'Dashboard statistike su dostupne samo na Pro planu.',
      );
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: 0,
      maxCount: 0,
      tier: tier,
    );
  }

  /// Može li admin koristiti napredne izveštaje
  Future<LimitCheckResult> canUseAdvancedReports(String companyId) async {
    final sub = await getSubscription(companyId);
    final tier = sub?.effectiveTier ?? SubscriptionTier.free;

    if (!tier.canUseAdvancedReports) {
      return LimitCheckResult(
        allowed: false,
        currentCount: 0,
        maxCount: 0,
        tier: tier,
        requiresUpgrade: true,
        message: 'Napredni izveštaji su dostupni samo na Pro planu.',
      );
    }

    return LimitCheckResult(
      allowed: true,
      currentCount: 0,
      maxCount: 0,
      tier: tier,
    );
  }

  // ─── SOFT LOCK — LIFO kad pretplata istekne ───────────────────────────────

  /// Kada pretplata istekne, zaključava radnike koji su iznad
  /// novog efektivnog limita (LIFO — zadnji dodani gube pristup prvi).
  Future<void> applyWorkerSoftLock(String companyId) async {
    final sub = await getSubscription(companyId);
    final effectiveLimit = sub?.effectiveTier.baseWorkerLimit ??
        SubscriptionTier.free.baseWorkerLimit;

    final workersSnap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('active_status', isEqualTo: true)
        .where('soft_locked', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .get();

    if (workersSnap.size <= effectiveLimit) return;

    // Zaključaj poslednje dodane koji su iznad limita (LIFO)
    final toBlock = workersSnap.docs.take(workersSnap.size - effectiveLimit);
    final batch = _db.batch();
    for (final doc in toBlock) {
      batch.update(doc.reference, {'soft_locked': true});
    }
    await batch.commit();
  }

  // ─── SEAT ADDON-I ─────────────────────────────────────────────────────────

  /// Dodaje seat addon nakon potvrde kupovine od RevenueCat-a.
  /// U produkciji poziva Cloud Function webhook — ovde simuliramo direktno.
  Future<void> addSeatAddon({
    required String companyId,
    required String productId,
    required int seats,
  }) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final now = DateTime.now();
    final addon = SeatAddon(
      productId: productId,
      seats: seats,
      purchasedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      status: 'active',
    );

    final sub = SubscriptionModel.fromFirestore(snap.docs.first);
    final updatedAddons = [...sub.seatAddons, addon];

    await snap.docs.first.reference.update({
      'seat_addons': updatedAddons.map((a) => a.toMap()).toList(),
    });
  }

  /// Ukloni istekle seat addon-e i primeni LIFO lock ako treba
  Future<void> cleanupExpiredAddons(String companyId) async {
    final snap = await _db
        .collection('subscriptions')
        .where('company_id', isEqualTo: companyId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final sub = SubscriptionModel.fromFirestore(snap.docs.first);
    final activeAddons = sub.activeSeatAddons;

    // Ažuriraj Firestore samo ako ima nešto za ukloniti
    if (activeAddons.length != sub.seatAddons.length) {
      await snap.docs.first.reference.update({
        'seat_addons': activeAddons.map((a) => a.toMap()).toList(),
      });

      // Primeni LIFO lock za radnike koji su sad iznad novog limita
      await applyWorkerSoftLock(companyId);
    }
  }

  // ─── OBNOVI / PROMENI PLAN ────────────────────────────────────────────────

  /// Obnovi pretplatu (poziva se iz RevenueCat webhook-a ili simulacije)
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
    };

    if (snap.docs.isEmpty) {
      final docRef = _db.collection('subscriptions').doc();
      await docRef.set({
        'company_id': companyId,
        'seat_addons': [],
        'created_at': Timestamp.fromDate(DateTime.now()),
        ...data,
      });
    } else {
      await snap.docs.first.reference.update(data);
    }

    // Otključaj soft-locked radnike do novog limita
    await _unlockWorkers(companyId, tier.baseWorkerLimit);
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
      'seat_addons': [],
    });

    await applyWorkerSoftLock(companyId);
  }

  Future<void> _unlockWorkers(String companyId, int upToLimit) async {
    final snap = await _db
        .collection('users')
        .where('current_company_id', isEqualTo: companyId)
        .where('soft_locked', isEqualTo: true)
        .orderBy('created_at', descending: false)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    int unlocked = 0;
    for (final doc in snap.docs) {
      if (unlocked >= upToLimit) break;
      batch.update(doc.reference, {'soft_locked': false});
      unlocked++;
    }
    await batch.commit();
  }
}

// ─── LIMIT CHECK RESULT ───────────────────────────────────────────────────────

class LimitCheckResult {
  final bool allowed;
  final int currentCount;
  final int maxCount;
  final SubscriptionTier tier;
  final bool requiresUpgrade;
  final bool requiresSeatAddon;
  final bool isSoftLocked;
  final String? message;

  const LimitCheckResult({
    required this.allowed,
    required this.currentCount,
    required this.maxCount,
    required this.tier,
    this.requiresUpgrade = false,
    this.requiresSeatAddon = false,
    this.isSoftLocked = false,
    this.message,
  });
}
