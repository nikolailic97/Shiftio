import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/subscription_provider.dart';
import '../../screens/admin/subscription_screen.dart';

/// Prikazuje se na vrhu ekrana kad je pretplata istekla.
/// Nema grace perioda — soft lock se primenjuje odmah.
class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();

    // Ako je pretplata aktivna, ne prikazuj ništa
    if (subProvider.isActive) return const SizedBox.shrink();

    // Prikaži samo kad je istekla
    if (!subProvider.isExpired) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: AppColors.error,
        child: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pretplata je istekla. Radnici iznad Free limita nemaju pristup.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
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
