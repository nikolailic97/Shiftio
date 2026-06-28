import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../../data/models/shift_model.dart';

// ─── DATA MODELI ──────────────────────────────────────────────────────────────

class _WorkerStat {
  final UserModel worker;
  final int totalMinutes;
  final int overtimeMinutes; // iznad 40h/sedmica u tekućoj sedmici
  final int shiftsCount;

  const _WorkerStat({
    required this.worker,
    required this.totalMinutes,
    required this.overtimeMinutes,
    required this.shiftsCount,
  });

  double get totalHours => totalMinutes / 60.0;
  double get overtimeHours => overtimeMinutes / 60.0;
  bool get hasOvertime => overtimeMinutes > 0;
}

class _DashboardData {
  final int totalMinutesMonth;
  final int activeWorkersCount;
  final List<_WorkerStat> workerStats;
  final DateTime generatedAt;

  const _DashboardData({
    required this.totalMinutesMonth,
    required this.activeWorkersCount,
    required this.workerStats,
    required this.generatedAt,
  });

  double get totalHoursMonth => totalMinutesMonth / 60.0;

  double get avgHoursPerWorker =>
      activeWorkersCount > 0 ? totalHoursMonth / activeWorkersCount : 0;

  List<_WorkerStat> get top3Workers {
    final sorted = [...workerStats]
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    return sorted.take(3).toList();
  }

  List<_WorkerStat> get overtimeWorkers =>
      workerStats.where((w) => w.hasOvertime).toList()
        ..sort((a, b) => b.overtimeMinutes.compareTo(a.overtimeMinutes));
}

// ─── EKRAN ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _error;
  _DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = context.read<AuthProvider>().currentUser;
      final companyId = user?.currentCompanyId;
      if (companyId == null) throw Exception('Firma nije pronađena');

      final now = DateTime.now();

      // Granice tekućeg meseca
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      // Granice tekuće sedmice (pon–ned)
      final weekStart =
          DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      // Dohvati sve radnike
      final workers = await _firestoreService.getTeamMembers(companyId);

      // Dohvati sve smene za mesec (jedan query za sve radnike)
      final monthShiftsSnap = await _db
          .collection('shifts')
          .where('company_id', isEqualTo: companyId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      final monthShifts =
          monthShiftsSnap.docs.map((d) => ShiftModel.fromFirestore(d)).toList();

      // Dohvati smene za tekuću sedmicu (za overtime tracking)
      final weekShiftsSnap = await _db
          .collection('shifts')
          .where('company_id', isEqualTo: companyId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      final weekShifts =
          weekShiftsSnap.docs.map((d) => ShiftModel.fromFirestore(d)).toList();

      // Agregiraj po radniku
      final workerStats = <_WorkerStat>[];
      int totalMinutesMonth = 0;

      for (final worker in workers) {
        // Mesečni sati
        final workerMonthShifts =
            monthShifts.where((s) => s.workerId == worker.uid).toList();
        final monthMinutes =
            workerMonthShifts.fold<int>(0, (sum, s) => sum + s.durationMinutes);

        // Sedmični sati (za overtime)
        final workerWeekShifts =
            weekShifts.where((s) => s.workerId == worker.uid).toList();
        final weekMinutes =
            workerWeekShifts.fold<int>(0, (sum, s) => sum + s.durationMinutes);

        // Prekovremeno = iznad 40h (2400 min) u sedmici
        final overtimeMinutes = weekMinutes > 2400 ? weekMinutes - 2400 : 0;

        totalMinutesMonth += monthMinutes;

        workerStats.add(_WorkerStat(
          worker: worker,
          totalMinutes: monthMinutes,
          overtimeMinutes: overtimeMinutes,
          shiftsCount: workerMonthShifts.length,
        ));
      }

      if (mounted) {
        setState(() {
          _data = _DashboardData(
            totalMinutesMonth: totalMinutesMonth,
            activeWorkersCount: workers.length,
            workerStats: workerStats,
            generatedAt: now,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Greška pri učitavanju podataka';
          _isLoading = false;
        });
      }
    }
  }

  static const _meseci = [
    '',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final monthName = '${_meseci[now.month]} ${now.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadData)
              : _data == null
                  ? const SizedBox()
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Naslov perioda
                        Text(
                          'Ovaj mesec — $monthName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ─── Karte sa statistikama ──────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Ukupno sati',
                                value:
                                    '${_data!.totalHoursMonth.toStringAsFixed(1)}h',
                                icon: Icons.schedule_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Aktivnih radnika',
                                value: '${_data!.activeWorkersCount}',
                                icon: Icons.group_rounded,
                                color: AppColors.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Prosek po radniku',
                                value:
                                    '${_data!.avgHoursPerWorker.toStringAsFixed(1)}h',
                                icon: Icons.person_rounded,
                                color: AppColors.adminColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Prekovremenih',
                                value: '${_data!.overtimeWorkers.length}',
                                icon: Icons.timer_rounded,
                                color: _data!.overtimeWorkers.isEmpty
                                    ? AppColors.success
                                    : AppColors.warning,
                                subtitle: _data!.overtimeWorkers.isEmpty
                                    ? 'radnika'
                                    : 'ove sedmice',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ─── Top 3 radnika ─────────────────────────────────
                        _SectionTitle(label: 'Najviše radili ovaj mesec'),
                        const SizedBox(height: 12),

                        if (_data!.top3Workers.isEmpty)
                          _EmptyState(
                            icon: Icons.bar_chart_rounded,
                            message: 'Nema smena ovaj mesec',
                          )
                        else
                          ..._data!.top3Workers.asMap().entries.map(
                                (entry) => _TopWorkerCard(
                                  rank: entry.key + 1,
                                  stat: entry.value,
                                ),
                              ),

                        const SizedBox(height: 28),

                        // ─── Prekovremeni rad ──────────────────────────────
                        _SectionTitle(label: 'Prekovremeni rad — ova sedmica'),
                        const SizedBox(height: 6),
                        Text(
                          'Zakon RS: max 40h/sedmici. Radnici ispod su prešli limit.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),

                        if (_data!.overtimeWorkers.isEmpty)
                          _EmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            message: 'Svi radnici su u okviru 40h ove sedmice',
                            color: AppColors.success,
                          )
                        else
                          ..._data!.overtimeWorkers.map(
                            (stat) => _OvertimeCard(stat: stat),
                          ),

                        const SizedBox(height: 28),

                        // ─── Svi radnici ───────────────────────────────────
                        _SectionTitle(label: 'Svi radnici — ovaj mesec'),
                        const SizedBox(height: 12),

                        if (_data!.workerStats.isEmpty)
                          _EmptyState(
                            icon: Icons.group_outlined,
                            message: 'Nema radnika u firmi',
                          )
                        else ...[
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text('Radnik',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                                Expanded(
                                  child: Text('Smena',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                                Expanded(
                                  child: Text('Sati',
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: _data!.workerStats
                                  .asMap()
                                  .entries
                                  .map((entry) => _WorkerRow(
                                        stat: entry.value,
                                        isLast: entry.key ==
                                            _data!.workerStats.length - 1,
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Text(
                          'Generisano: ${DateFormat('dd.MM.yyyy HH:mm').format(_data!.generatedAt)}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
    );
  }
}

// ─── WIDGETI ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.textSecondaryLight,
          ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
          if (subtitle != null)
            Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _TopWorkerCard extends StatelessWidget {
  final int rank;
  final _WorkerStat stat;

  const _TopWorkerCard({required this.rank, required this.stat});

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // zlato
      case 2:
        return const Color(0xFFC0C0C0); // srebro
      default:
        return const Color(0xFFCD7F32); // bronza
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarColor = AppColors.avatarColors[
        stat.worker.uid.hashCode.abs() % AppColors.avatarColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rankColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: _rankColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: avatarColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                stat.worker.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.worker.fullName, style: theme.textTheme.titleLarge),
                Text(
                  '${stat.shiftsCount} smena',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Sati
          Text(
            '${stat.totalHours.toStringAsFixed(1)}h',
            style: theme.textTheme.headlineSmall
                ?.copyWith(color: _rankColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  final _WorkerStat stat;

  const _OvertimeCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarColor = AppColors.avatarColors[
        stat.worker.uid.hashCode.abs() % AppColors.avatarColors.length];
    final totalWeekHours = (stat.totalMinutes > 0
            ? stat.totalMinutes + stat.overtimeMinutes
            : stat.overtimeMinutes + 2400) /
        60.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.warning.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: avatarColor, shape: BoxShape.circle),
            child: Center(
              child: Text(stat.worker.initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.worker.fullName, style: theme.textTheme.titleLarge),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 12, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '+${stat.overtimeHours.toStringAsFixed(1)}h prekovremeno',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalWeekHours.toStringAsFixed(1)}h',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.warning, fontWeight: FontWeight.w800),
              ),
              Text('ove sedmice', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkerRow extends StatelessWidget {
  final _WorkerStat stat;
  final bool isLast;

  const _WorkerRow({required this.stat, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarColor = AppColors.avatarColors[
        stat.worker.uid.hashCode.abs() % AppColors.avatarColors.length];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Avatar + ime
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: avatarColor, shape: BoxShape.circle),
                      child: Center(
                        child: Text(stat.worker.initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stat.worker.fullName,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Smene
              Expanded(
                child: Text(
                  '${stat.shiftsCount}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              // Sati
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${stat.totalHours.toStringAsFixed(1)}h',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: AppColors.primary),
                    ),
                    if (stat.hasOvertime) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.warning),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: c, size: 32),
          const SizedBox(height: 10),
          Text(message,
              style: theme.textTheme.bodyMedium?.copyWith(color: c),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    );
  }
}
