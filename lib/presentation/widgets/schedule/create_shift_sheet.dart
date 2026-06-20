import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/auth_provider.dart';
import 'shift_time_picker.dart';

class CreateShiftSheet extends StatefulWidget {
  final DateTime selectedDate;

  const CreateShiftSheet({super.key, required this.selectedDate});

  @override
  State<CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends State<CreateShiftSheet> {
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  int _durationMinutes = 480;
  final _noteController = TextEditingController();
  bool _sendNotification = true;
  bool _isLoading = false;
  List<String> _selectedWorkerIds = [];
  bool _selectAll = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _durationHours => _durationMinutes ~/ 60;
  int get _durationMins => _durationMinutes % 60;

  TimeOfDay get _endTime {
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = startMins + _durationMinutes;
    return TimeOfDay(hour: (endMins ~/ 60) % 24, minute: endMins % 60);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _durationLabel {
    if (_durationHours == 0) return '${_durationMins}min';
    if (_durationMins == 0) return '${_durationHours}h';
    return '${_durationHours}h ${_durationMins}min';
  }

  void _toggleSelectAll(List<UserModel> team) {
    setState(() {
      _selectAll = !_selectAll;
      _selectedWorkerIds = _selectAll ? team.map((w) => w.uid).toList() : [];
    });
  }

  void _toggleWorker(String uid) {
    setState(() {
      if (_selectedWorkerIds.contains(uid)) {
        _selectedWorkerIds.remove(uid);
      } else {
        _selectedWorkerIds.add(uid);
      }
      _selectAll = false;
    });
  }

  Future<void> _handleCreate() async {
    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Izaberite najmanje jednog radnika'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_durationMinutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Trajanje smene mora biti veće od 0'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().currentUser!;
    final scheduleProvider = context.read<ScheduleProvider>();

    final startDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final success = await scheduleProvider.createShift(
      companyId: user.currentCompanyId!,
      workerIds: _selectedWorkerIds,
      startTime: startDateTime,
      durationMinutes: _durationMinutes,
      date: widget.selectedDate,
      noteAdmin: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      sendNotification: _sendNotification,
    );

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context, success);
  }

  void _openRecurring() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ScheduleProvider>(),
        child: ChangeNotifierProvider.value(
          value: context.read<AuthProvider>(),
          child: RecurringScheduleSheet(
            preselectedWorkerIds: _selectedWorkerIds,
            startTime: _startTime,
            durationMinutes: _durationMinutes,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final team = context.watch<ScheduleProvider>().teamMembers;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20,
                  MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nova smena', style: theme.textTheme.headlineMedium),
                            Text(_formatDate(widget.selectedDate),
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Početak smene
                  Text('Početak smene', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ShiftioTimePicker(
                    initialTime: _startTime,
                    onTimeChanged: (t) => setState(() => _startTime = t),
                  ),

                  const SizedBox(height: 20),

                  // Trajanje
                  Text('Trajanje', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ShiftioDurationPicker(
                    initialHours: _durationHours,
                    initialMinutes: _durationMins,
                    onDurationChanged: (mins) =>
                        setState(() => _durationMinutes = mins),
                  ),

                  const SizedBox(height: 12),

                  // Auto kraj
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Text('Kraj smene: ',
                            style: theme.textTheme.bodyMedium),
                        Text(_fmt(_endTime),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: AppColors.primary)),
                        Text('  (+$_durationLabel)',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Radnici
                  Row(
                    children: [
                      Text('Radnici', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _toggleSelectAll(team),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _selectAll ? 'Poništi sve' : 'Izaberi sve',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (team.isEmpty)
                    Center(
                        child: Text('Nema radnika u firmi',
                            style: theme.textTheme.bodyMedium))
                  else
                    ...team.map((worker) {
                      final isSelected =
                          _selectedWorkerIds.contains(worker.uid);
                      final color = AppColors.avatarColors[
                          worker.uid.hashCode.abs() %
                              AppColors.avatarColors.length];
                      return GestureDetector(
                        onTap: () => _toggleWorker(worker.uid),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.08)
                                : isDark
                                    ? AppColors.cardDark
                                    : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                                child: Center(
                                    child: Text(worker.initials,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(worker.fullName,
                                        style: theme.textTheme.titleLarge),
                                    Text(
                                      worker.role == UserRole.manager
                                          ? 'Menadžer'
                                          : 'Radnik',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Napomena
                  Text('Napomena (opciono)', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'npr. Prva smena — šank'),
                  ),

                  const SizedBox(height: 16),

                  // Notifikacija
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_outlined,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('Pošalji notifikaciju radnicima',
                                style: theme.textTheme.titleLarge)),
                        Switch(
                          value: _sendNotification,
                          onChanged: (v) =>
                              setState(() => _sendNotification = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreate,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(_selectedWorkerIds.isEmpty
                            ? 'Kreiraj smenu'
                            : 'Kreiraj smenu (${_selectedWorkerIds.length})'),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _openRecurring,
                    icon: const Icon(Icons.repeat_rounded, size: 18),
                    label: const Text('Postavi ponavljajući raspored'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'januar', 'februar', 'mart', 'april', 'maj', 'jun',
      'jul', 'avgust', 'septembar', 'oktobar', 'novembar', 'decembar'
    ];
    const days = [
      'Ponedeljak', 'Utorak', 'Sreda', 'Četvrtak',
      'Petak', 'Subota', 'Nedjelja'
    ];
    return '${days[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]}';
  }
}

// ─── Recurring Schedule Sheet ─────────────────────────────────────────────────
class RecurringScheduleSheet extends StatefulWidget {
  final List<String> preselectedWorkerIds;
  final TimeOfDay startTime;
  final int durationMinutes;

  const RecurringScheduleSheet({
    super.key,
    required this.preselectedWorkerIds,
    required this.startTime,
    required this.durationMinutes,
  });

  @override
  State<RecurringScheduleSheet> createState() =>
      _RecurringScheduleSheetState();
}

class _RecurringScheduleSheetState extends State<RecurringScheduleSheet> {
  late TimeOfDay _startTime;
  late int _durationMinutes;
  late List<String> _selectedWorkerIds;

  // Dani u tjednu: 1=Pon, 2=Uto...7=Ned
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5};

  // Odabrani mjeseci
  final Set<int> _selectedMonths = {};
  bool _selectAllMonths = false;
  int _selectedYear = DateTime.now().year;

  final _noteController = TextEditingController();
  bool _sendNotification = true;
  bool _isLoading = false;

  final List<String> _weekdayLabels = [
    'Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'
  ];

  final List<String> _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun',
    'Jul', 'Avg', 'Sep', 'Okt', 'Nov', 'Dec'
  ];

  final List<String> _monthFullLabels = [
    'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
    'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar'
  ];

  @override
  void initState() {
    super.initState();
    _startTime = widget.startTime;
    _durationMinutes = widget.durationMinutes;
    _selectedWorkerIds = List.from(widget.preselectedWorkerIds);

    // Default: trenutni i sljedeći mjesec
    final now = DateTime.now();
    _selectedMonths.add(now.month);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _durationHours => _durationMinutes ~/ 60;
  int get _durationMins => _durationMinutes % 60;

  void _toggleMonth(int month) {
    setState(() {
      if (_selectedMonths.contains(month)) {
        _selectedMonths.remove(month);
      } else {
        _selectedMonths.add(month);
      }
      _selectAllMonths = _selectedMonths.length == 12;
    });
  }

  void _toggleSelectAllMonths() {
    setState(() {
      _selectAllMonths = !_selectAllMonths;
      if (_selectAllMonths) {
        _selectedMonths.addAll(List.generate(12, (i) => i + 1));
      } else {
        _selectedMonths.clear();
      }
    });
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  // Generiši sve datume koji zadovoljavaju kriterije
  List<DateTime> _generateDates() {
    final dates = <DateTime>[];

    for (final month in _selectedMonths) {
      final daysInMonth =
          DateTime(_selectedYear, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_selectedYear, month, day);
        if (_selectedWeekdays.contains(date.weekday)) {
          // Preskoči prošle datume
          if (!date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
            dates.add(date);
          }
        }
      }
    }

    dates.sort();
    return dates;
  }

  Future<void> _handleCreate() async {
    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Izaberite najmanje jednog radnika'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Izaberite najmanje jedan dan u tjednu'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_selectedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Izaberite najmanje jedan mjesec'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_durationMinutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Trajanje smene mora biti veće od 0'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final dates = _generateDates();

    // Potvrda
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Potvrdi kreiranje'),
        content: Text(
          'Kreiraće se ${dates.length} smena za ${_selectedWorkerIds.length} radnika.\n\n'
          'Ukupno: ${dates.length * _selectedWorkerIds.length} smena.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kreiraj'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().currentUser!;
    final scheduleProvider = context.read<ScheduleProvider>();

    int created = 0;
    for (final date in dates) {
      final startDateTime = DateTime(
        date.year, date.month, date.day,
        _startTime.hour, _startTime.minute,
      );

      final success = await scheduleProvider.createShift(
        companyId: user.currentCompanyId!,
        workerIds: _selectedWorkerIds,
        startTime: startDateTime,
        durationMinutes: _durationMinutes,
        date: date,
        noteAdmin: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        sendNotification: _sendNotification,
      );

      if (success) created++;
    }

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kreirano $created smena!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final team = context.watch<ScheduleProvider>().teamMembers;
    final dates = _generateDates();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20,
                  MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ponavljajući raspored',
                                style: theme.textTheme.headlineMedium),
                            Text('Postavi smene za više dana odjednom',
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Početak smene
                  Text('Početak smene', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ShiftioTimePicker(
                    initialTime: _startTime,
                    onTimeChanged: (t) => setState(() => _startTime = t),
                  ),

                  const SizedBox(height: 20),

                  // Trajanje
                  Text('Trajanje', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  ShiftioDurationPicker(
                    initialHours: _durationHours,
                    initialMinutes: _durationMins,
                    onDurationChanged: (mins) =>
                        setState(() => _durationMinutes = mins),
                  ),

                  const SizedBox(height: 20),

                  // Dani u tjednu
                  Text('Dani u tjednu', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final isSelected = _selectedWeekdays.contains(day);
                      final isWeekend = day >= 6;

                      return GestureDetector(
                        onTap: () => _toggleWeekday(day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 42,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : isDark
                                    ? AppColors.cardDark
                                    : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayLabels[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : isWeekend
                                          ? AppColors.error
                                          : isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // Godina
                  Row(
                    children: [
                      Text('Godina i mjeseci',
                          style: theme.textTheme.titleLarge),
                      const Spacer(),
                      // Godina selector
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: () =>
                                setState(() => _selectedYear--),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Text(
                            '$_selectedYear',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () =>
                                setState(() => _selectedYear++),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Select all months
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleSelectAllMonths,
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: _selectAllMonths
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _selectAllMonths
                                      ? AppColors.primary
                                      : isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                  width: 2,
                                ),
                              ),
                              child: _selectAllMonths
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text('Cijela godina',
                                style: theme.textTheme.titleLarge),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Months grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, i) {
                      final month = i + 1;
                      final isSelected = _selectedMonths.contains(month);
                      final isPast = DateTime(_selectedYear, month + 1, 0)
                          .isBefore(DateTime.now());

                      return GestureDetector(
                        onTap: isPast ? null : () => _toggleMonth(month),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : isPast
                                    ? (isDark
                                        ? AppColors.dividerDark
                                        : AppColors.dividerLight)
                                    : isDark
                                        ? AppColors.cardDark
                                        : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _monthLabels[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : isPast
                                        ? (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight)
                                        : isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Radnici
                  Row(
                    children: [
                      Text('Radnici', style: theme.textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedWorkerIds.length == team.length) {
                              _selectedWorkerIds.clear();
                            } else {
                              _selectedWorkerIds =
                                  team.map((w) => w.uid).toList();
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          _selectedWorkerIds.length == team.length
                              ? 'Poništi sve'
                              : 'Izaberi sve',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ...team.map((worker) {
                    final isSelected =
                        _selectedWorkerIds.contains(worker.uid);
                    final color = AppColors.avatarColors[
                        worker.uid.hashCode.abs() %
                            AppColors.avatarColors.length];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedWorkerIds.remove(worker.uid);
                          } else {
                            _selectedWorkerIds.add(worker.uid);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.08)
                              : isDark
                                  ? AppColors.cardDark
                                  : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                              child: Center(
                                  child: Text(worker.initials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(worker.fullName,
                                    style: theme.textTheme.titleLarge)),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Napomena
                  Text('Napomena (opciono)', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'npr. Redovna smena'),
                  ),

                  const SizedBox(height: 16),

                  // Notifikacija
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_outlined,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('Pošalji notifikacije radnicima',
                                style: theme.textTheme.titleLarge)),
                        Switch(
                          value: _sendNotification,
                          onChanged: (v) =>
                              setState(() => _sendNotification = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Preview
                  if (dates.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${dates.length} dana × ${_selectedWorkerIds.length} radnika = '
                              '${dates.length * _selectedWorkerIds.length} smena ukupno',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreate,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(dates.isEmpty
                            ? 'Izaberite dane i mjesece'
                            : 'Kreiraj ${dates.length * _selectedWorkerIds.length} smena'),
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