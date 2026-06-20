import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionTier { free, standard, pro }

enum SubscriptionStatus { active, expired, pastDue, gracePeriod }

enum SubscriptionCycle { monthly, yearly }

extension SubscriptionTierExt on SubscriptionTier {
  String get value {
    switch (this) {
      case SubscriptionTier.free:
        return 'free';
      case SubscriptionTier.standard:
        return 'standard';
      case SubscriptionTier.pro:
        return 'pro';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.standard:
        return 'Standard';
      case SubscriptionTier.pro:
        return 'Pro';
    }
  }

  // ─── Limiti po planu ───────────────────────────────────────────────────────
  int get maxCompanies {
    switch (this) {
      case SubscriptionTier.free:
        return 1;
      case SubscriptionTier.standard:
        return 2;
      case SubscriptionTier.pro:
        return 5;
    }
  }

  int get maxWorkers {
    switch (this) {
      case SubscriptionTier.free:
        return 5;
      case SubscriptionTier.standard:
        return 15;
      case SubscriptionTier.pro:
        return 50;
    }
  }

  int get maxDailyNotifications {
    switch (this) {
      case SubscriptionTier.free:
        return 30;
      case SubscriptionTier.standard:
        return 200;
      case SubscriptionTier.pro:
        return 500;
    }
  }

  bool get canExport {
    return this != SubscriptionTier.free;
  }

  double get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.standard:
        return 10;
      case SubscriptionTier.pro:
        return 40;
    }
  }

  double get yearlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.standard:
        return 99;
      case SubscriptionTier.pro:
        return 399;
    }
  }

  static SubscriptionTier fromString(String s) {
    switch (s) {
      case 'standard':
        return SubscriptionTier.standard;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }
}

extension SubscriptionStatusExt on SubscriptionStatus {
  String get value {
    switch (this) {
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.pastDue:
        return 'past_due';
      case SubscriptionStatus.gracePeriod:
        return 'grace_period';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Aktivna';
      case SubscriptionStatus.expired:
        return 'Istekla';
      case SubscriptionStatus.pastDue:
        return 'Dospjela uplata';
      case SubscriptionStatus.gracePeriod:
        return 'Grace Period';
    }
  }

  static SubscriptionStatus fromString(String s) {
    switch (s) {
      case 'expired':
        return SubscriptionStatus.expired;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'grace_period':
        return SubscriptionStatus.gracePeriod;
      default:
        return SubscriptionStatus.active;
    }
  }
}

extension SubscriptionCycleExt on SubscriptionCycle {
  String get value => this == SubscriptionCycle.monthly ? 'monthly' : 'yearly';
  String get label =>
      this == SubscriptionCycle.monthly ? 'Mjesečno' : 'Godišnje';

  static SubscriptionCycle fromString(String s) =>
      s == 'yearly' ? SubscriptionCycle.yearly : SubscriptionCycle.monthly;
}

class SubscriptionModel {
  final String subscriptionId;
  final String companyId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final SubscriptionCycle cycle;
  final DateTime endDate;
  final DateTime? gracePeriodEnd;
  final int dailyNotificationCount;
  final DateTime? lastNotificationReset;
  final String? revenuecatCustomerId;
  final DateTime createdAt;

  const SubscriptionModel({
    required this.subscriptionId,
    required this.companyId,
    required this.tier,
    required this.status,
    required this.cycle,
    required this.endDate,
    this.gracePeriodEnd,
    this.dailyNotificationCount = 0,
    this.lastNotificationReset,
    this.revenuecatCustomerId,
    required this.createdAt,
  });

  /// Da li je pretplata aktivna (uključuje grace period)
  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.gracePeriod;

  /// Da li je u grace periodu
  bool get isInGracePeriod => status == SubscriptionStatus.gracePeriod;

  /// Da li je istekla (bez grace perioda)
  bool get isExpired => status == SubscriptionStatus.expired;

  /// Efektivni tier — ako je expired, vraća free
  SubscriptionTier get effectiveTier =>
      isExpired ? SubscriptionTier.free : tier;

  /// Broj dana do isteka grace perioda
  int get gracePeriodDaysLeft {
    if (gracePeriodEnd == null) return 0;
    final diff = gracePeriodEnd!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Preostale notifikacije danas
  int get remainingDailyNotifications {
    final max = effectiveTier.maxDailyNotifications;
    return (max - dailyNotificationCount).clamp(0, max);
  }

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      subscriptionId: doc.id,
      companyId: data['company_id'] ?? '',
      tier: SubscriptionTierExt.fromString(data['tier'] ?? 'free'),
      status: SubscriptionStatusExt.fromString(data['status'] ?? 'active'),
      cycle: SubscriptionCycleExt.fromString(data['cycle'] ?? 'monthly'),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gracePeriodEnd: data['grace_period_end'] != null
          ? (data['grace_period_end'] as Timestamp).toDate()
          : null,
      dailyNotificationCount: data['daily_notification_count'] ?? 0,
      lastNotificationReset: data['last_notification_reset'] != null
          ? (data['last_notification_reset'] as Timestamp).toDate()
          : null,
      revenuecatCustomerId: data['revenuecat_customer_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Default free subscription za novu firmu
  factory SubscriptionModel.freeTier(String companyId) {
    return SubscriptionModel(
      subscriptionId: '',
      companyId: companyId,
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      cycle: SubscriptionCycle.monthly,
      endDate: DateTime(2099),
      dailyNotificationCount: 0,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'tier': tier.value,
      'status': status.value,
      'cycle': cycle.value,
      'end_date': Timestamp.fromDate(endDate),
      'grace_period_end':
          gracePeriodEnd != null ? Timestamp.fromDate(gracePeriodEnd!) : null,
      'daily_notification_count': dailyNotificationCount,
      'last_notification_reset': lastNotificationReset != null
          ? Timestamp.fromDate(lastNotificationReset!)
          : null,
      'revenuecat_customer_id': revenuecatCustomerId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
