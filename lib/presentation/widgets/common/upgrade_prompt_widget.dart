import 'package:flutter/material.dart';
import 'package:shiftio/presentation/screens/admin/subscription_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/subscription_model.dart';

/// Prikazuje se kao bottom sheet kad korisnik pokuša da pristupi
/// feature-u koji nije dostupan na njegovom trenutnom planu.
///
/// Primer upotrebe:
/// ```dart
/// final check = await _subService.canExport(companyId);
/// if (!check.allowed && mounted) {
///   UpgradePromptWidget.show(
///     context,
///     requiredTier: SubscriptionTier.standard,
///     featureName: 'Export podataka',
///     featureIcon: Icons.download_rounded,
///   );
///   return;
/// }
/// ```
class UpgradePromptWidget extends StatelessWidget {
  final SubscriptionTier requiredTier;
  final String featureName;
  final IconData featureIcon;
  final String? customMessage;

  const UpgradePromptWidget({
    super.key,
    required this.requiredTier,
    required this.featureName,
    required this.featureIcon,
    this.customMessage,
  });

  static Future<void> show(
    BuildContext context, {
    required SubscriptionTier requiredTier,
    required String featureName,
    required IconData featureIcon,
    String? customMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpgradePromptWidget(
        requiredTier: requiredTier,
        featureName: featureName,
        featureIcon: featureIcon,
        customMessage: customMessage,
      ),
    );
  }

  Color get _tierColor {
    switch (requiredTier) {
      case SubscriptionTier.standard:
        return AppColors.primary;
      case SubscriptionTier.pro:
        return AppColors.adminColor;
      default:
        return AppColors.primary;
    }
  }

  String get _priceLabel {
    switch (requiredTier) {
      case SubscriptionTier.standard:
        return '€10 / mesec';
      case SubscriptionTier.pro:
        return '€29 / mesec';
      default:
        return 'Besplatno';
    }
  }

  String get _defaultMessage {
    switch (requiredTier) {
      case SubscriptionTier.standard:
        return '$featureName je dostupan od Standard plana.\n'
            'Nadogradite za €10/mes i odmah dobijte pristup.';
      case SubscriptionTier.pro:
        return '$featureName je dostupan samo na Pro planu.\n'
            'Nadogradite za €29/mes i otključajte sve Pro funkcije.';
      default:
        return '$featureName nije dostupan na vašem planu.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Ikonica
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(featureIcon, color: _tierColor, size: 34),
          ),
          const SizedBox(height: 16),

          // Naziv feature-a
          Text(
            featureName,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Plan badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _tierColor.withOpacity(0.3)),
            ),
            child: Text(
              '${requiredTier.label} plan — $_priceLabel',
              style: TextStyle(
                color: _tierColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Poruka
          Text(
            customMessage ?? _defaultMessage,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Nadogradi dugme
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _tierColor,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text('Nadogradi na ${requiredTier.label}'),
          ),
          const SizedBox(height: 10),

          // Otkaži
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('Možda kasnije'),
          ),
        ],
      ),
    );
  }
}

/// Kompaktna inline verzija za banner prikaz unutar ekrana
/// (npr. kad Free korisnik vidi Export tab ali ne može da klikne)
class UpgradePromptBanner extends StatelessWidget {
  final SubscriptionTier requiredTier;
  final String featureName;
  final IconData featureIcon;

  const UpgradePromptBanner({
    super.key,
    required this.requiredTier,
    required this.featureName,
    required this.featureIcon,
  });

  Color get _tierColor => requiredTier == SubscriptionTier.pro
      ? AppColors.adminColor
      : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tierColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tierColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(featureIcon, color: _tierColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(featureName, style: theme.textTheme.titleLarge),
                Text(
                  'Dostupno na ${requiredTier.label} planu',
                  style: theme.textTheme.bodySmall?.copyWith(color: _tierColor),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Nadogradi',
              style: TextStyle(color: _tierColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
