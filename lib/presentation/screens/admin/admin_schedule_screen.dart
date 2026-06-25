import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftio/presentation/widgets/schedule/shift_card_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/schedule/day_picker_widget.dart';
import '../../widgets/schedule/create_shift_sheet.dart';
import 'admin_shift_detail_screen.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user?.currentCompanyId != null) {
        context.read<ScheduleProvider>().initForAdmin(user!.currentCompanyId!);
      }
    });
  }

  Future<void> _openCreateSheet() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.currentCompanyId == null) return;

    // Kreiranje smena je dostupno na svim planovima — bez subscription provjere.
    // Broj radnika koji se mogu DODATI u tim je ograničen po planu,
    // ali kreiranje smena za već-dodane radnike nema limita.
    final scheduleProvider = context.read<ScheduleProvider>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ScheduleProvider>(),
        child: ChangeNotifierProvider.value(
          value: context.read<AuthProvider>(),
          child: CreateShiftSheet(
            selectedDate: scheduleProvider.selectedDate,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteShift(ShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obriši smenu'),
        content: Text(
          'Da li ste sigurni da želite da obrišete smenu ${shift.timeRangeFormatted}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<ScheduleProvider>().deleteShift(shift.shiftId);
    }
  }

  Future<void> _confirmDeleteBatch(String batchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obriši sve smene'),
        content: const Text(
          'Ovo će obrisati smene za sve radnike u ovom terminu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši sve'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<ScheduleProvider>().deleteShiftsBatch(batchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduleProvider = context.watch<ScheduleProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    final groupedShifts = _groupShifts(scheduleProvider.shiftsForDay);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Raspored',
                          style: theme.textTheme.displayMedium,
                        ),
                        Text(
                          _formatSelectedDate(scheduleProvider.selectedDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
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
                  companyId: user?.currentCompanyId,
                );
              },
            ),

            const SizedBox(height: 8),

            // ─── Shift Count ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                scheduleProvider.isLoading
                    ? 'Učitavanje...'
                    : '${scheduleProvider.shiftsForDay.length} ${_shiftLabel(scheduleProvider.shiftsForDay.length)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),

            // ─── Shift List ───────────────────────────────────────────────────
            Expanded(
              child: scheduleProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : scheduleProvider.shiftsForDay.isEmpty
                      ? _EmptySchedule(onAdd: _openCreateSheet)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: groupedShifts.length,
                          itemBuilder: (context, index) {
                            final group = groupedShifts[index];
                            final shifts = group['shifts'] as List<ShiftModel>;
                            final workers = scheduleProvider.teamMembers
                                .where((w) =>
                                    shifts.any((s) => s.workerId == w.uid))
                                .toList();

                            if (shifts.length == 1) {
                              final shift = shifts.first;
                              final worker = scheduleProvider.teamMembers
                                  .where((w) => w.uid == shift.workerId)
                                  .firstOrNull;

                              return ShiftCard(
                                shift: shift,
                                worker: worker,
                                isAdminView: true,
                                onDelete: () => _confirmDeleteShift(shift),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ChangeNotifierProvider.value(
                                      value: context.read<ScheduleProvider>(),
                                      child: AdminShiftDetailScreen(
                                        shift: shift,
                                        worker: worker,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return GroupedShiftCard(
                              shifts: shifts,
                              workers: workers,
                              onDeleteBatch: shifts.first.batchId != null
                                  ? () =>
                                      _confirmDeleteBatch(shifts.first.batchId!)
                                  : null,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider.value(
                                    value: context.read<ScheduleProvider>(),
                                    child: AdminShiftDetailScreen(
                                      shift: shifts.first,
                                      worker: scheduleProvider.teamMembers
                                          .where((w) =>
                                              w.uid == shifts.first.workerId)
                                          .firstOrNull,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      // ─── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  List<Map<String, dynamic>> _groupShifts(List<ShiftModel> shifts) {
    final Map<String, List<ShiftModel>> groups = {};
    for (final shift in shifts) {
      final key = shift.batchId ?? shift.shiftId;
      groups.putIfAbsent(key, () => []).add(shift);
    }
    return groups.values.map((shifts) => {'shifts': shifts}).toList()
      ..sort((a, b) {
        final aShifts = a['shifts'] as List<ShiftModel>;
        final bShifts = b['shifts'] as List<ShiftModel>;
        return aShifts.first.startTime.compareTo(bShifts.first.startTime);
      });
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

  String _shiftLabel(int count) {
    if (count == 1) return 'smena';
    if (count >= 2 && count <= 4) return 'smene';
    return 'smena';
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptySchedule extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySchedule({required this.onAdd});

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
              Icons.calendar_today_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('Nema smena', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Dodajte smenu za ovaj dan',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Dodaj smenu'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
