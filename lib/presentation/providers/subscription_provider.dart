import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shiftio/data/models/subscription_model.dart';
import 'package:shiftio/data/services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();

  SubscriptionModel? _subscription;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<SubscriptionModel?>? _sub;

  SubscriptionModel? get subscription => _subscription;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Shortcuts ────────────────────────────────────────────────────────────────
  SubscriptionTier get tier =>
      _subscription?.effectiveTier ?? SubscriptionTier.free;

  SubscriptionStatus get status =>
      _subscription?.status ?? SubscriptionStatus.active;

  bool get isActive => _subscription?.isActive ?? true;
  bool get isInGracePeriod => _subscription?.isInGracePeriod ?? false;
  bool get isExpired => _subscription?.isExpired ?? false;
  bool get canExport => tier.canExport;
  int get maxWorkers => tier.maxWorkers;
  int get maxDailyNotifications => tier.maxDailyNotifications;
  int get gracePeriodDaysLeft => _subscription?.gracePeriodDaysLeft ?? 0;
  int get remainingNotifications =>
      _subscription?.remainingDailyNotifications ?? tier.maxDailyNotifications;

  // ─── INIT ─────────────────────────────────────────────────────────────────────

  void init(String companyId) {
    _isLoading = true;
    notifyListeners();

    _sub = _service.watchSubscription(companyId).listen((sub) {
      _subscription = sub;
      _isLoading = false;
      notifyListeners();

      // Auto-provjeri istek
      if (sub != null) _checkExpiry(sub, companyId);
    });
  }

  // ─── PROVJERA ISTEKA ──────────────────────────────────────────────────────────

  void _checkExpiry(SubscriptionModel sub, String companyId) {
    final now = DateTime.now();

    if (sub.status == SubscriptionStatus.active && sub.endDate.isBefore(now)) {
      // Pretplata istekla — pokreni grace period
      _service.startGracePeriod(companyId);
    } else if (sub.status == SubscriptionStatus.gracePeriod &&
        sub.gracePeriodEnd != null &&
        sub.gracePeriodEnd!.isBefore(now)) {
      // Grace period istekao — expire
      _service.expireSubscription(companyId);
    }
  }

  // ─── LIMIT PROVJERE ───────────────────────────────────────────────────────────

  Future<LimitCheckResult> canAddWorker(String companyId) async {
    return await _service.canAddWorker(companyId);
  }

  Future<LimitCheckResult> canCreateShift(String companyId) async {
    return await _service.canCreateShift(companyId);
  }

  Future<LimitCheckResult> canSendNotification(String companyId) async {
    return await _service.canSendNotification(companyId);
  }

  Future<LimitCheckResult> canExportData(String companyId) async {
    return await _service.canExport(companyId);
  }

  // ─── OBNOVI PRETPLATU ─────────────────────────────────────────────────────────

  Future<bool> renewSubscription({
    required String companyId,
    required SubscriptionTier tier,
    required SubscriptionCycle cycle,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.renewSubscription(
        companyId: companyId,
        tier: tier,
        cycle: cycle,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri obnavljanju pretplate';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── NOTIFIKACIJE ─────────────────────────────────────────────────────────────

  Future<void> incrementNotificationCount(String companyId, int count) async {
    await _service.incrementNotificationCount(companyId, count);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
