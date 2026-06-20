import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/subscription_model.dart';
import '../../../data/services/revenuecat_service.dart';
import '../../../data/services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final RevenueCatService _rcService = RevenueCatService();
  final SubscriptionService _subService = SubscriptionService();

  SubscriptionCycle _selectedCycle = SubscriptionCycle.monthly;
  List<Package> _packages = [];
  bool _isLoadingPackages = true;
  bool _isPurchasing = false;
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoadingPackages = true);
    final packages = await _rcService.getPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        _isLoadingPackages = false;
      });
    }
  }

  Future<void> _handlePurchase(SubscriptionTier tier) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.currentCompanyId == null) return;

    if (tier == SubscriptionTier.free) {
      await _devModePurchase(tier, user!.currentCompanyId!);
      return;
    }

    final productId = _rcService.getProductId(tier, _selectedCycle);
    Package? targetPackage;
    for (final pkg in _packages) {
      if (pkg.storeProduct.identifier == productId) {
        targetPackage = pkg;
        break;
      }
    }

    // Dev mode fallback ako paketi nisu učitani
    if (targetPackage == null) {
      await _devModePurchase(tier, user!.currentCompanyId!);
      return;
    }

    setState(() {
      _isPurchasing = true;
      _purchasingProductId = productId;
    });

    final result = await _rcService.purchasePackage(targetPackage);

    setState(() {
      _isPurchasing = false;
      _purchasingProductId = null;
    });

    if (!mounted) return;

    if (result.success) {
      await _subService.renewSubscription(
        companyId: user!.currentCompanyId!,
        tier: tier,
        cycle: _selectedCycle,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pretplata uspješno aktivirana!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (!result.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Greška pri kupovini.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _devModePurchase(SubscriptionTier tier, String companyId) async {
    setState(() => _isPurchasing = true);
    await _subService.renewSubscription(
      companyId: companyId,
      tier: tier,
      cycle: _selectedCycle,
    );
    setState(() => _isPurchasing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('[DEV] ${tier.label} plan aktiviran!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isPurchasing = true);
    final info = await _rcService.restorePurchases();
    setState(() => _isPurchasing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(info != null
            ? 'Kupovine obnovljene!'
            : 'Nema prethodnih kupovina.'),
        backgroundColor:
            info != null ? AppColors.success : AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subProvider = context.watch<SubscriptionProvider>();
    final currentTier = subProvider.tier;
    final sub = subProvider.subscription;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja pretplata'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _handleRestore,
            child: const Text('Obnovi kupovinu'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CurrentPlanCard(
            tier: currentTier,
            status: subProvider.status,
            sub: sub,
            graceDaysLeft: subProvider.gracePeriodDaysLeft,
          ),
          const SizedBox(height: 28),
          Text('Odaberi plan', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),

          // Cycle toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CycleButton(
                    label: 'Mjesečno',
                    isSelected: _selectedCycle == SubscriptionCycle.monthly,
                    onTap: () => setState(
                        () => _selectedCycle = SubscriptionCycle.monthly),
                  ),
                ),
                Expanded(
                  child: _CycleButton(
                    label: 'Godišnje',
                    badge: 'Uštedi ~20%',
                    isSelected: _selectedCycle == SubscriptionCycle.yearly,
                    onTap: () => setState(
                        () => _selectedCycle = SubscriptionCycle.yearly),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingPackages)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            _PlanCard(
              tier: SubscriptionTier.free,
              cycle: _selectedCycle,
              isCurrentPlan: currentTier == SubscriptionTier.free,
              isPurchasing: _isPurchasing && _purchasingProductId == '',
              onSelect: () => _handlePurchase(SubscriptionTier.free),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              tier: SubscriptionTier.standard,
              cycle: _selectedCycle,
              isCurrentPlan: currentTier == SubscriptionTier.standard,
              isPurchasing: _isPurchasing &&
                  _purchasingProductId ==
                      _rcService.getProductId(
                          SubscriptionTier.standard, _selectedCycle),
              onSelect: () => _handlePurchase(SubscriptionTier.standard),
            ),
            const SizedBox(height: 12),
            _PlanCard(
              tier: SubscriptionTier.pro,
              cycle: _selectedCycle,
              isCurrentPlan: currentTier == SubscriptionTier.pro,
              isPurchasing: _isPurchasing &&
                  _purchasingProductId ==
                      _rcService.getProductId(
                          SubscriptionTier.pro, _selectedCycle),
              onSelect: () => _handlePurchase(SubscriptionTier.pro),
              isRecommended: true,
            ),
          ],

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '• Otkazivanje je moguće u bilo kom trenutku\n'
              '• Grace period od 7 dana nakon isteka\n'
              '• Podaci ostaju sačuvani pri downgrade-u\n'
              '• Plaćanje putem Google Play / App Store-a',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final SubscriptionModel? sub;
  final int graceDaysLeft;

  const _CurrentPlanCard({
    required this.tier,
    required this.status,
    this.sub,
    required this.graceDaysLeft,
  });

  Color get _statusColor {
    switch (status) {
      case SubscriptionStatus.active: return AppColors.success;
      case SubscriptionStatus.gracePeriod: return AppColors.warning;
      case SubscriptionStatus.expired:
      case SubscriptionStatus.pastDue: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd.MM.yyyy');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Aktivni plan',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.8))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColor),
                ),
                child: Text(status.label,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${tier.label} Plan',
              style: theme.textTheme.displayMedium
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.group_rounded, label: '${tier.maxWorkers} radnika'),
              _InfoChip(icon: Icons.notifications_rounded, label: '${tier.maxDailyNotifications}/dan'),
              _InfoChip(icon: Icons.download_rounded, label: tier.canExport ? 'Export ✓' : 'Bez exporta'),
            ],
          ),
          if (status == SubscriptionStatus.gracePeriod) ...[
            const SizedBox(height: 12),
            Text('⚠️ Grace period: još $graceDaysLeft dana',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
          if (sub != null && sub!.endDate.year != 2099) ...[
            const SizedBox(height: 6),
            Text('Važi do: ${fmt.format(sub!.endDate)}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final SubscriptionCycle cycle;
  final bool isCurrentPlan;
  final bool isPurchasing;
  final bool isRecommended;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.tier,
    required this.cycle,
    required this.isCurrentPlan,
    required this.isPurchasing,
    required this.onSelect,
    this.isRecommended = false,
  });

  double get _price => cycle == SubscriptionCycle.monthly ? tier.monthlyPrice : tier.yearlyPrice;

  String get _priceLabel {
    if (_price == 0) return 'Besplatno';
    return '€${_price.toStringAsFixed(0)} ${cycle == SubscriptionCycle.monthly ? "/ mj" : "/ god"}';
  }

  Color get _tierColor {
    switch (tier) {
      case SubscriptionTier.free: return AppColors.textSecondaryLight;
      case SubscriptionTier.standard: return AppColors.primary;
      case SubscriptionTier.pro: return AppColors.adminColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isCurrentPlan
                ? _tierColor.withOpacity(0.06)
                : (isDark ? AppColors.cardDark : AppColors.cardLight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isCurrentPlan ? _tierColor : Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(tier.label,
                      style: theme.textTheme.headlineSmall?.copyWith(color: _tierColor)),
                  const Spacer(),
                  Text(_priceLabel,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: _tierColor, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              _Feature(label: '${tier.maxWorkers} radnika', icon: Icons.group_rounded, color: _tierColor),
              _Feature(label: '${tier.maxDailyNotifications} notif. / dan', icon: Icons.notifications_rounded, color: _tierColor),
              _Feature(
                  label: tier.canExport ? 'Export Excel / CSV' : 'Bez exporta',
                  icon: tier.canExport ? Icons.download_rounded : Icons.block_rounded,
                  color: tier.canExport ? _tierColor : AppColors.textSecondaryLight,
                  disabled: !tier.canExport),
              if (tier == SubscriptionTier.pro)
                _Feature(label: 'Ned. / Mjes. / God. izvještaji', icon: Icons.bar_chart_rounded, color: _tierColor),
              const SizedBox(height: 14),
              if (isCurrentPlan)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _tierColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('Trenutni plan',
                        style: TextStyle(color: _tierColor, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: isPurchasing ? null : onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tierColor,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                  child: isPurchasing
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(tier == SubscriptionTier.free ? 'Prebaci na Free' : 'Odaberi ${tier.label}'),
                ),
            ],
          ),
        ),
        if (isRecommended)
          Positioned(
            top: -10,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: _tierColor, borderRadius: BorderRadius.circular(20)),
              child: const Text('⭐ Preporučeno',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool disabled;

  const _Feature({required this.label, required this.icon, required this.color, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: disabled ? AppColors.textSecondaryLight : color),
          const SizedBox(width: 8),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: disabled ? AppColors.textSecondaryLight : null,
                    decoration: disabled ? TextDecoration.lineThrough : null,
                  )),
        ],
      ),
    );
  }
}

class _CycleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _CycleButton({required this.label, required this.isSelected, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14)),
            if (badge != null)
              Text(badge!,
                  style: TextStyle(
                      color: isSelected ? Colors.white.withOpacity(0.8) : AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}