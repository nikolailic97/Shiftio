import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../../data/services/leave_policy_service.dart';
import '../../providers/auth_provider.dart';

class LeaveBalanceWidget extends StatefulWidget {
  const LeaveBalanceWidget({super.key});

  @override
  State<LeaveBalanceWidget> createState() => _LeaveBalanceWidgetState();
}

class _LeaveBalanceWidgetState extends State<LeaveBalanceWidget> {
  final LeavePolicyService _service = LeavePolicyService();

  LeavePolicyModel? _policy;
  Map<String, int> _remaining = {};
  Map<String, int> _used = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.currentCompanyId == null) return;

    setState(() => _isLoading = true);
    try {
      final policy = await _service.getPolicy(user!.currentCompanyId!);
      final remaining = await _service.getWorkerRemainingDays(
        userId: user.uid,
        companyId: user.currentCompanyId!,
        year: DateTime.now().year,
      );
      final used = await _service.getWorkerUsedDays(
        userId: user.uid,
        year: DateTime.now().year,
        companyId: user.currentCompanyId!,
      );

      if (mounted) {
        setState(() {
          _policy = policy;
          _remaining = remaining;
          _used = used;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (_policy == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Stanje odmora ${DateTime.now().year}',
                  style: theme.textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: _load,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppColors.textSecondaryLight,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._policy!.leaveTypes.map((type) {
            final total = type.daysPerYear;
            final usedDays = _used[type.id] ?? 0;
            final remainingDays = _remaining[type.id] ?? total;
            final progress = total > 0 ? remainingDays / total : 0.0;

            Color typeColor;
            switch (type.id) {
              case 'vacation':
                typeColor = AppColors.primary;
                break;
              case 'sick':
                typeColor = AppColors.warning;
                break;
              case 'slava':
                typeColor = AppColors.adminColor;
                break;
              default:
                typeColor = AppColors.success;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child:
                            Text(type.name, style: theme.textTheme.titleLarge),
                      ),
                      Text(
                        '$remainingDays / $total dana',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: typeColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                      minHeight: 6,
                    ),
                  ),
                  if (usedDays > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Iskorišćeno: $usedDays dana',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
