import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/subscription_model.dart';

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // ─── RevenueCat API ključevi ─────────────────────────────────────────────────
  // VAŽNO: Zamijeni sa tvojim pravim ključevima iz RevenueCat dashboarda
  static const String _androidApiKey = 'goog_XXXXXXXXXXXXXXXXXXXX';
  static const String _iosApiKey = 'appl_XXXXXXXXXXXXXXXXXXXX';

  // ─── Product ID-evi (moraju se poklapati sa Google Play / App Store) ──────────
  static const String _standardMonthlyId = 'shiftio_standard_monthly';
  static const String _standardYearlyId = 'shiftio_standard_yearly';
  static const String _proMonthlyId = 'shiftio_pro_monthly';
  static const String _proYearlyId = 'shiftio_pro_yearly';

  // ─── Offering ID ──────────────────────────────────────────────────────────────
  static const String _offeringId = 'shiftio_main';

  bool _isInitialized = false;

  // ─── INIT ─────────────────────────────────────────────────────────────────────

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      final configuration = PurchasesConfiguration(
        // Android ili iOS ključ ovisno o platformi
        defaultTargetPlatform == TargetPlatform.android
            ? _androidApiKey
            : _iosApiKey,
      )..appUserID = userId;

      await Purchases.configure(configuration);
      _isInitialized = true;

      debugPrint('RevenueCat inicijalizovan za korisnika: $userId');
    } catch (e) {
      debugPrint('RevenueCat greška pri inicijalizaciji: $e');
    }
  }

  // ─── DOHVATI OFFERINGS ────────────────────────────────────────────────────────

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Greška pri dohvaćanju ponuda: $e');
      return null;
    }
  }

  Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(_offeringId) ?? offerings.current;
      return offering?.availablePackages ?? [];
    } catch (e) {
      debugPrint('Greška pri dohvaćanju paketa: $e');
      return [];
    }
  }

  // ─── KUPI PAKET ───────────────────────────────────────────────────────────────

  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return PurchaseResult(
        success: true,
        customerInfo: customerInfo,
      );
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult(
          success: false,
          cancelled: true,
          errorMessage: 'Kupovina otkazana.',
        );
      }
      return PurchaseResult(
        success: false,
        errorMessage: _handlePurchaseError(e),
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        errorMessage: 'Neočekivana greška: $e',
      );
    }
  }

  // ─── RESTORE PURCHASES ────────────────────────────────────────────────────────

  Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      debugPrint('Greška pri obnavljanju kupovina: $e');
      return null;
    }
  }

  // ─── DOHVATI CUSTOMER INFO ────────────────────────────────────────────────────

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('Greška pri dohvaćanju customer info: $e');
      return null;
    }
  }

  // ─── MAPIRANJE Product ID → Tier/Cycle ───────────────────────────────────────

  SubscriptionTier getTierFromProductId(String productId) {
    if (productId.contains('standard')) return SubscriptionTier.standard;
    if (productId.contains('pro')) return SubscriptionTier.pro;
    return SubscriptionTier.free;
  }

  SubscriptionCycle getCycleFromProductId(String productId) {
    if (productId.contains('yearly')) return SubscriptionCycle.yearly;
    return SubscriptionCycle.monthly;
  }

  String getProductId(SubscriptionTier tier, SubscriptionCycle cycle) {
    switch (tier) {
      case SubscriptionTier.standard:
        return cycle == SubscriptionCycle.yearly
            ? _standardYearlyId
            : _standardMonthlyId;
      case SubscriptionTier.pro:
        return cycle == SubscriptionCycle.yearly ? _proYearlyId : _proMonthlyId;
      default:
        return '';
    }
  }

  // ─── PROVJERI AKTIVNU PRETPLATU ───────────────────────────────────────────────

  Future<ActiveSubscriptionInfo?> checkActiveSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlements = customerInfo.entitlements.active;

      if (entitlements.isEmpty) return null;

      // Provjeri Pro entitlement
      if (entitlements.containsKey('pro')) {
        return ActiveSubscriptionInfo(
          tier: SubscriptionTier.pro,
          expiresAt: entitlements['pro']!.expirationDate != null
              ? DateTime.parse(entitlements['pro']!.expirationDate!)
              : null,
        );
      }

      // Provjeri Standard entitlement
      if (entitlements.containsKey('standard')) {
        return ActiveSubscriptionInfo(
          tier: SubscriptionTier.standard,
          expiresAt: entitlements['standard']!.expirationDate != null
              ? DateTime.parse(entitlements['standard']!.expirationDate!)
              : null,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Greška pri provjeri pretplate: $e');
      return null;
    }
  }

  // ─── ERROR HANDLER ────────────────────────────────────────────────────────────

  String _handlePurchaseError(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Kupovina nije dozvoljena na ovom uređaju.';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'Nevažeća kupovina. Pokušajte ponovo.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Proizvod trenutno nije dostupan.';
      case PurchasesErrorCode.networkError:
        return 'Greška mreže. Provjeri internet konekciju.';
      case PurchasesErrorCode.storeProblemError:
        return 'Greška prodavnice. Pokušaj ponovo.';
      default:
        return 'Greška pri kupovini. Pokušajte ponovo.';
    }
  }
}

// ─── Helper modeli ────────────────────────────────────────────────────────────

class PurchaseResult {
  final bool success;
  final bool cancelled;
  final CustomerInfo? customerInfo;
  final String? errorMessage;

  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.customerInfo,
    this.errorMessage,
  });
}

class ActiveSubscriptionInfo {
  final SubscriptionTier tier;
  final DateTime? expiresAt;

  const ActiveSubscriptionInfo({
    required this.tier,
    this.expiresAt,
  });
}
