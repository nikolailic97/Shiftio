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

  // ─── Shortcuts ──────────────────────────────────────────────────────────────

  SubscriptionTier get tier =>
      _subscription?.effectiveTier ?? SubscriptionTier.free;

  SubscriptionStatus get status =>
      _subscription?.status ?? SubscriptionStatus.active;

  bool get isActive => _subscription?.isActive ?? true;
  bool get isExpired => _subscription?.isExpired ?? false;

  // Funkcionalnosti po tier-u
  bool get canExport => tier.canExport;
  bool get canUseAdvancedReports => tier.canUseAdvancedReports;
  bool get canUseDashboard => tier.canUseDashboard;
  bool get canUseManagerRole => tier.canUseManagerRole;
  bool get canUseSeatAddons => tier.canUseSeatAddons;
  bool get hasPrioritySupport => tier.hasPrioritySupport;

  // Limiti
  int get baseWorkerLimit => tier.baseWorkerLimit;
  int get totalWorkerLimit =>
      _subscription?.totalWorkerLimit ?? tier.baseWorkerLimit;
  int get maxCompanies => tier.maxCompanies;

  // Seat addon-i
  int get totalAddonSeats => _subscription?.totalAddonSeats ?? 0;
  List<SeatAddon> get activeSeatAddons => _subscription?.activeSeatAddons ?? [];

  // ─── INIT ────────────────────────────────────────────────────────────────────

  void init(String companyId) {
    _isLoading = true;
    notifyListeners();

    _sub = _service.watchSubscription(companyId).listen((sub) {
      _subscription = sub;
      _isLoading = false;
      notifyListeners();

      // Provjeri istek
      if (sub != null) _checkExpiry(sub, companyId);
    });
  }

  // ─── PROVJERA ISTEKA ─────────────────────────────────────────────────────────

  void _checkExpiry(SubscriptionModel sub, String companyId) {
    final now = DateTime.now();

    // Pretplata istekla — odmah expire, bez grace perioda
    if (sub.status == SubscriptionStatus.active &&
        sub.endDate.year != 2099 &&
        sub.endDate.isBefore(now)) {
      _service.expireSubscription(companyId);
    }

    // Provjeri istekle seat addon-e
    final hasExpiredAddons = sub.seatAddons.any((a) => !a.isActive);
    if (hasExpiredAddons) {
      _service.cleanupExpiredAddons(companyId);
    }
  }

  // ─── LIMIT PROVJERE ──────────────────────────────────────────────────────────

  Future<LimitCheckResult> canAddWorker(String companyId) async {
    return await _service.canAddWorker(companyId);
  }

  Future<LimitCheckResult> canExportData(String companyId) async {
    return await _service.canExport(companyId);
  }

  Future<LimitCheckResult> canUseDashboardData(String companyId) async {
    return await _service.canUseDashboard(companyId);
  }

  Future<LimitCheckResult> canUseAdvancedReportsData(String companyId) async {
    return await _service.canUseAdvancedReports(companyId);
  }

  // ─── SEAT ADDON-I ─────────────────────────────────────────────────────────────

  Future<bool> purchaseSeatAddon({
    required String companyId,
    required String productId,
    required int seats,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.addSeatAddon(
        companyId: companyId,
        productId: productId,
        seats: seats,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Greška pri dodavanju seat addon-a';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
