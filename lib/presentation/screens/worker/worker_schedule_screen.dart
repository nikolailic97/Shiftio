import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftio/presentation/widgets/schedule/shift_card_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/schedule/day_picker_widget.dart';

class WorkerScheduleScreen extends StatefulWidget {
  const WorkerScheduleScreen({super.key});

  @override
  State<WorkerScheduleScreen> createState() => _WorkerScheduleScreenState();
}

class _WorkerScheduleScreenState extends State<WorkerScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null && user.currentCompanyId != null) {
        context
            .read<ScheduleProvider>()
            .initForWorker(user.uid, user.currentCompanyId!);
      }
    });
  }

  void _openShiftDetail(ShiftModel shift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ScheduleProvider>(),
        child: _ShiftDetailSheet(shift: shift),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduleProvider = context.watch<ScheduleProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Moj raspored', style: theme.textTheme.displayMedium),
                  Text(
                    _formatSelectedDate(scheduleProvider.selectedDate),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // ─── Day Picker ───────────────────────────────────────────────────
            DayPickerWidget(
              selectedDate: scheduleProvider.selectedDate,
              daysWithShifts: scheduleProvider.daysWithShifts,
              onDateSelected: (date) {
                scheduleProvider.selectDate(
                  date,
                  workerId: user?.uid,
                );
              },
            ),

            const SizedBox(height: 8),

            // ─── Shift List ───────────────────────────────────────────────────
            Expanded(
              child: scheduleProvider.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : scheduleProvider.shiftsForDay.isEmpty
                      ? _EmptyWorkerSchedule()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: scheduleProvider.shiftsForDay.length,
                          itemBuilder: (context, index) {
                            final shift = scheduleProvider.shiftsForDay[index];
                            return ShiftCard(
                              shift: shift,
                              isAdminView: false,
                              onTap: () => _openShiftDetail(shift),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    const months = [
      'januar',
      'februar',
      'mart',
      'april',
      'maj',
      'jun',
      'jul',
      'avgust',
      'septembar',
      'oktobar',
      'novembar',
      'decembar'
    ];
    const days = [
      'Ponedeljak',
      'Utorak',
      'Sreda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedjelja'
    ];
    return '${days[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]}';
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyWorkerSchedule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.free_breakfast_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('Slobodan dan!', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Nemate dodeljenih smena za ovaj dan',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─── Shift Detail Bottom Sheet ────────────────────────────────────────────────
class _ShiftDetailSheet extends StatefulWidget {
  final ShiftModel shift;

  const _ShiftDetailSheet({required this.shift});

  @override
  State<_ShiftDetailSheet> createState() => _ShiftDetailSheetState();
}

class _ShiftDetailSheetState extends State<_ShiftDetailSheet> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _commentSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.shift.workerComment != null) {
      _commentController.text = widget.shift.workerComment!;
      _commentSent = true;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => _isSubmitting = true);

    final success = await context
        .read<ScheduleProvider>()
        .addWorkerComment(widget.shift.shiftId, comment);

    setState(() {
      _isSubmitting = false;
      if (success) _commentSent = true;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komentar je poslat poslodavcu'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shift = widget.shift;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text('Detalji smene', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 20),

                  // Vreme
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.timeRangeFormatted,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              shift.durationFormatted,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Napomena admina
                  if (shift.noteAdmin != null &&
                      shift.noteAdmin!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Napomena', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cardDark
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        shift.noteAdmin!,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Komentar sekcija
                  Text('Vaš komentar', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Obavestite poslodavca o eventualnim izmenama',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    enabled: !_commentSent,
                    decoration: InputDecoration(
                      hintText: 'npr. Kasnim 15 minuta, ne mogu doći...',
                      suffixIcon: _commentSent
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (!_commentSent)
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitComment,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Pošalji komentar'),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Komentar poslat poslodavcu',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
