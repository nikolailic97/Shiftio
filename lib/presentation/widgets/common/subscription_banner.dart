import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/subscription_provider.dart';
import '../../screens/admin/subscription_screen.dart';

class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();

    if (subProvider.isActive && !subProvider.isInGracePeriod) {
      return const SizedBox.shrink();
    }

    final isExpired = subProvider.isExpired;
    final isGrace = subProvider.isInGracePeriod;

    if (!isExpired && !isGrace) return const SizedBox.shrink();

    final bgColor = isExpired ? AppColors.error : AppColors.warning;
    final icon = isExpired ? Icons.lock_rounded : Icons.warning_amber_rounded;
    final message = isExpired
        ? 'Pretplata je istekla. Planer je zaključan.'
        : 'Pretplata ističe — još ${subProvider.gracePeriodDaysLeft} dana grace perioda.';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: bgColor,
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'Obnovi →',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
