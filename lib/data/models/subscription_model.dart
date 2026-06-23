import 'package:cloud_firestore/cloud_firestore.dart';

// ─── ENUMI ────────────────────────────────────────────────────────────────────

enum SubscriptionTier { free, standard, pro }

enum SubscriptionStatus { active, expired, pastDue }

enum SubscriptionCycle { monthly, yearly }

// ─── SEAT ADDON MODEL ─────────────────────────────────────────────────────────

/// Predstavlja jedan kupljeni seat addon (+1, +5, +10, +20 radnika).
/// Čuva se kao lista unutar subscriptions/{companyId} dokumenta.
class SeatAddon {
  final String productId; // npr. 'shiftio_seats_10'
  final int seats; // broj radnika koje dodaje
  final DateTime purchasedAt;
  final DateTime expiresAt;
  final String status; // 'active' | 'expired' | 'cancelled'

  const SeatAddon({
    required this.productId,
    required this.seats,
    required this.purchasedAt,
    required this.expiresAt,
    this.status = 'active',
  });

  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());

  factory SeatAddon.fromMap(Map<String, dynamic> data) {
    return SeatAddon(
      productId: data['product_id'] ?? '',
      seats: data['seats'] ?? 0,
      purchasedAt: (data['purchased_at'] as Timestamp).toDate(),
      expiresAt: (data['expires_at'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'seats': seats,
      'purchased_at': Timestamp.fromDate(purchasedAt),
      'expires_at': Timestamp.fromDate(expiresAt),
      'status': status,
    };
  }
}

// ─── SEAT ADDON DEFINICIJE (za UI prikaz i kupovinu) ─────────────────────────

class SeatAddonDefinition {
  final String productId;
  final int seats;
  final double priceMonthly; // €0.70 po radniku
  final String label;

  const SeatAddonDefinition({
    required this.productId,
    required this.seats,
    required this.priceMonthly,
    required this.label,
  });
}

const kSeatAddonDefinitions = [
  SeatAddonDefinition(
    productId: 'shiftio_seats_1',
    seats: 1,
    priceMonthly: 0.70,
    label: '+1 radnik',
  ),
  SeatAddonDefinition(
    productId: 'shiftio_seats_5',
    seats: 5,
    priceMonthly: 3.50,
    label: '+5 radnika',
  ),
  SeatAddonDefinition(
    productId: 'shiftio_seats_10',
    seats: 10,
    priceMonthly: 7.00,
    label: '+10 radnika',
  ),
  SeatAddonDefinition(
    productId: 'shiftio_seats_20',
    seats: 20,
    priceMonthly: 14.00,
    label: '+20 radnika',
  ),
];

// ─── SUBSCRIPTION TIER EXTENSION ─────────────────────────────────────────────

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

  // ─── Limiti ───────────────────────────────────────────────────────────────

  /// Broj radnika u base planu (pre seat addon-a)
  int get baseWorkerLimit {
    switch (this) {
      case SubscriptionTier.free:
        return 10;
      case SubscriptionTier.standard:
        return 30;
      case SubscriptionTier.pro:
        return 60;
    }
  }

  /// Broj firmi koje admin može da kreira/upravlja
  int get maxCompanies {
    switch (this) {
      case SubscriptionTier.free:
        return 1;
      case SubscriptionTier.standard:
        return 1;
      case SubscriptionTier.pro:
        return 2;
    }
  }

  // ─── Funkcionalnosti ──────────────────────────────────────────────────────

  bool get canExport => this != SubscriptionTier.free;

  bool get canUseAdvancedReports => this == SubscriptionTier.pro;

  bool get canUseSeatAddons => this != SubscriptionTier.free;

  bool get canUseDashboard => this == SubscriptionTier.pro;

  bool get canUseManagerRole =>
      this == SubscriptionTier.standard || this == SubscriptionTier.pro;

  bool get hasPrioritySupport => this == SubscriptionTier.pro;

  // ─── Cene ─────────────────────────────────────────────────────────────────

  double get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.standard:
        return 10;
      case SubscriptionTier.pro:
        return 29;
    }
  }

  /// Godišnja cena (2 meseca gratis = 10 meseci)
  double get yearlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.standard:
        return 100; // uštedina €20
      case SubscriptionTier.pro:
        return 290; // uštedina €58
    }
  }

  double get yearlySaving => (monthlyPrice * 12) - yearlyPrice;

  // ─── Opis plana za UI ─────────────────────────────────────────────────────

  String get description {
    switch (this) {
      case SubscriptionTier.free:
        return 'Savršeno za mali tim koji počinje';
      case SubscriptionTier.standard:
        return 'Za rastuće firme kojima treba više';
      case SubscriptionTier.pro:
        return 'Potpuna kontrola i uvid za vaš biznis';
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

// ─── SUBSCRIPTION STATUS EXTENSION ───────────────────────────────────────────

extension SubscriptionStatusExt on SubscriptionStatus {
  String get value {
    switch (this) {
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.pastDue:
        return 'past_due';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Aktivna';
      case SubscriptionStatus.expired:
        return 'Istekla';
      case SubscriptionStatus.pastDue:
        return 'Dospela uplata';
    }
  }

  static SubscriptionStatus fromString(String s) {
    switch (s) {
      case 'expired':
        return SubscriptionStatus.expired;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      default:
        return SubscriptionStatus.active;
    }
  }
}

// ─── SUBSCRIPTION CYCLE EXTENSION ────────────────────────────────────────────

extension SubscriptionCycleExt on SubscriptionCycle {
  String get value => this == SubscriptionCycle.monthly ? 'monthly' : 'yearly';

  String get label =>
      this == SubscriptionCycle.monthly ? 'Mesečno' : 'Godišnje';

  static SubscriptionCycle fromString(String s) =>
      s == 'yearly' ? SubscriptionCycle.yearly : SubscriptionCycle.monthly;
}

// ─── SUBSCRIPTION MODEL ───────────────────────────────────────────────────────

class SubscriptionModel {
  final String subscriptionId;
  final String companyId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final SubscriptionCycle cycle;
  final DateTime endDate;
  final List<SeatAddon> seatAddons;
  final String? revenuecatCustomerId;
  final DateTime createdAt;

  const SubscriptionModel({
    required this.subscriptionId,
    required this.companyId,
    required this.tier,
    required this.status,
    required this.cycle,
    required this.endDate,
    this.seatAddons = const [],
    this.revenuecatCustomerId,
    required this.createdAt,
  });

  // ─── Computed getters ─────────────────────────────────────────────────────

  bool get isActive => status == SubscriptionStatus.active;

  bool get isExpired => status == SubscriptionStatus.expired;

  /// Efektivni tier — ako je expired, vraća free
  SubscriptionTier get effectiveTier =>
      isExpired ? SubscriptionTier.free : tier;

  /// Ukupan limit radnika = base limit + suma aktivnih seat addon-a
  int get totalWorkerLimit {
    final base = effectiveTier.baseWorkerLimit;
    final addonSeats = seatAddons
        .where((a) => a.isActive)
        .fold<int>(0, (sum, a) => sum + a.seats);
    return base + addonSeats;
  }

  /// Lista aktivnih seat addon-a
  List<SeatAddon> get activeSeatAddons =>
      seatAddons.where((a) => a.isActive).toList();

  /// Ukupno kupljenih seat addon radnika (aktivnih)
  int get totalAddonSeats =>
      activeSeatAddons.fold<int>(0, (sum, a) => sum + a.seats);

  // ─── Factory konstruktori ─────────────────────────────────────────────────

  factory SubscriptionModel.freeTier(String companyId) {
    return SubscriptionModel(
      subscriptionId: '',
      companyId: companyId,
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      cycle: SubscriptionCycle.monthly,
      endDate: DateTime(2099),
      seatAddons: const [],
      createdAt: DateTime.now(),
    );
  }

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final addonsList = (data['seat_addons'] as List<dynamic>?)
            ?.map((a) => SeatAddon.fromMap(a as Map<String, dynamic>))
            .toList() ??
        [];

    return SubscriptionModel(
      subscriptionId: doc.id,
      companyId: data['company_id'] ?? '',
      tier: SubscriptionTierExt.fromString(data['tier'] ?? 'free'),
      status: SubscriptionStatusExt.fromString(data['status'] ?? 'active'),
      cycle: SubscriptionCycleExt.fromString(data['cycle'] ?? 'monthly'),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seatAddons: addonsList,
      revenuecatCustomerId: data['revenuecat_customer_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'tier': tier.value,
      'status': status.value,
      'cycle': cycle.value,
      'end_date': Timestamp.fromDate(endDate),
      'seat_addons': seatAddons.map((a) => a.toMap()).toList(),
      'revenuecat_customer_id': revenuecatCustomerId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
