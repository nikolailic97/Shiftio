import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../../data/models/user_model.dart';

class ShiftCard extends StatelessWidget {
  final ShiftModel shift;
  final UserModel? worker; // null = worker pogled (zna ko je)
  final bool isAdminView;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ShiftCard({
    super.key,
    required this.shift,
    this.worker,
    this.isAdminView = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── Main Row ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Plava linija levo
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Vreme i trajanje
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.timeRangeFormatted,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shift.durationFormatted,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  // Worker avatar (admin pogled) ili ikone (worker pogled)
                  Row(
                    children: [
                      // Komentar indikator
                      if (shift.hasComment)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ),

                      if (isAdminView && worker != null)
                        _WorkerAvatar(worker: worker!),

                      if (isAdminView && onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),

                      if (!isAdminView)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Note ───────────────────────────────────────────────────────
            if (shift.noteAdmin != null && shift.noteAdmin!.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.inputFillDark
                      : AppColors.backgroundLight,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shift.noteAdmin!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Worker Avatar ────────────────────────────────────────────────────────────
class _WorkerAvatar extends StatelessWidget {
  final UserModel worker;

  const _WorkerAvatar({required this.worker});

  Color get _avatarColor {
    final index = worker.uid.hashCode % AppColors.avatarColors.length;
    return AppColors.avatarColors[index.abs()];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: _avatarColor,
        shape: BoxShape.circle,
      ),
      child: worker.profileImageUrl != null
          ? ClipOval(
              child: Image.network(
                worker.profileImageUrl!,
                fit: BoxFit.cover,
              ),
            )
          : Center(
              child: Text(
                worker.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

// ─── Admin Grouped Shift Card (više radnika na istom terminu) ─────────────────
class GroupedShiftCard extends StatelessWidget {
  final List<ShiftModel> shifts;
  final List<UserModel> workers;
  final VoidCallback? onTap;
  final VoidCallback? onDeleteBatch;

  const GroupedShiftCard({
    super.key,
    required this.shifts,
    required this.workers,
    this.onTap,
    this.onDeleteBatch,
  });

  ShiftModel get _first => shifts.first;
  bool get _hasAnyComment => shifts.any((s) => s.hasComment);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Plava linija
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Vreme
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _first.timeRangeFormatted,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _first.durationFormatted,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  // Avatari
                  Row(
                    children: [
                      if (_hasAnyComment)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ),
                      _AvatarStack(workers: workers),
                      if (onDeleteBatch != null)
                        IconButton(
                          onPressed: onDeleteBatch,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          padding: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_first.noteAdmin != null && _first.noteAdmin!.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.inputFillDark
                      : AppColors.backgroundLight,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _first.noteAdmin!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar Stack (preklapajući avatari) ──────────────────────────────────────
class _AvatarStack extends StatelessWidget {
  final List<UserModel> workers;
  final int maxVisible;

  const _AvatarStack({required this.workers, this.maxVisible = 3});

  @override
  Widget build(BuildContext context) {
    final visible = workers.take(maxVisible).toList();
    final extra = workers.length - maxVisible;

    return SizedBox(
      width: visible.length * 24.0 + 12 + (extra > 0 ? 28 : 0),
      height: 36,
      child: Stack(
        children: [
          ...visible.asMap().entries.map((e) {
            final index = e.key;
            final worker = e.value;
            final color = AppColors.avatarColors[
                worker.uid.hashCode.abs() % AppColors.avatarColors.length];
            return Positioned(
              left: index * 24.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.cardDark
                        : AppColors.cardLight,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    worker.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (extra > 0)
            Positioned(
              left: visible.length * 24.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.textSecondaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.cardDark
                        : AppColors.cardLight,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
