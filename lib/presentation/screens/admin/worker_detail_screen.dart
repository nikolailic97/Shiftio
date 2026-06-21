import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/leave_policy_service.dart';

class WorkerDetailScreen extends StatefulWidget {
  final UserModel worker;

  const WorkerDetailScreen({super.key, required this.worker});

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final FirestoreService _service = FirestoreService();
  final LeavePolicyService _leavePolicyService = LeavePolicyService();
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;
  int _hoursThisWeek = 0;
  int _hoursThisMonth = 0;
  int _hoursThisYear = 0;
  int _sickDaysThisYear = 0;
  int _vacationUsed = 0;

  // Godišnji odmor — sad dinamički iz LeavePolicyModel + requests,
  // ne iz statičkog worker.vacationDays polja (koje se rasinhronizovalo).
  int _vacationTotal = 20;
  int _vacationRemaining = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final companyId = widget.worker.currentCompanyId;

      if (companyId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Radnik nije dodeljen nijednoj firmi';
          });
        }
        return;
      }

      final weekStart =
          DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      final yearStart = DateTime(now.year, 1, 1);
      final yearEnd = DateTime(now.year + 1, 1, 1);

      // Radni sati — paralelno
      final results = await Future.wait([
        _service
            .getTotalMinutesForWorker(
              workerId: widget.worker.uid,
              companyId: companyId,
              from: weekStart,
              to: weekEnd,
            )
            .catchError((_) => 0),
        _service
            .getTotalMinutesForWorker(
              workerId: widget.worker.uid,
              companyId: companyId,
              from: monthStart,
              to: monthEnd,
            )
            .catchError((_) => 0),
        _service
            .getTotalMinutesForWorker(
              workerId: widget.worker.uid,
              companyId: companyId,
              from: yearStart,
              to: yearEnd,
            )
            .catchError((_) => 0),
      ]);

      // Radni sati su uspešno učitani u ovom trenutku — primeni ih odmah,
      // nezavisno od onoga što se desi ispod (bolovanje/godišnji), da pad u
      // jednom delu statistike ne obriše već dobijene rezultate iz drugog.
      if (mounted) {
        setState(() {
          _hoursThisWeek = (results[0] as int) ~/ 60;
          _hoursThisMonth = (results[1] as int) ~/ 60;
          _hoursThisYear = (results[2] as int) ~/ 60;
        });
      }

      // Bolovanje iz requests — odvojen try/catch da ne obori radne sate
      int sickDays = 0;
      try {
        sickDays = await _getSickDays(
          widget.worker.uid,
          companyId,
          yearStart,
          yearEnd,
        );
      } catch (_) {
        sickDays = 0;
      }

      // Godišnji odmor — kvota iz LeavePolicyModel, preostalo iz
      // LeavePolicyService.getWorkerRemainingDays (kvota - odobreni dani).
      // Odvojen try/catch da ne obori radne sate niti bolovanje.
      int vacationTotal = 20;
      int vacationRemaining = 0;
      int vacationUsed = 0;
      String? vacationError;
      try {
        final policy = await _leavePolicyService.getPolicy(companyId);
        final vacationType = policy.getType('vacation');
        final remainingByType =
            await _leavePolicyService.getWorkerRemainingDays(
          userId: widget.worker.uid,
          companyId: companyId,
          year: now.year,
        );

        vacationTotal = vacationType?.daysPerYear ?? 20;
        vacationRemaining = remainingByType['vacation'] ?? vacationTotal;
        vacationUsed =
            (vacationTotal - vacationRemaining).clamp(0, vacationTotal);
      } catch (_) {
        vacationError = 'Greška pri učitavanju godišnjeg odmora';
      }

      if (mounted) {
        setState(() {
          _sickDaysThisYear = sickDays;
          _vacationTotal = vacationTotal;
          _vacationRemaining = vacationRemaining;
          _vacationUsed = vacationUsed;
          _errorMessage = vacationError;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Greška pri učitavanju statistike';
        });
      }
    }
  }

  Future<int> _getSickDays(
      String userId, String companyId, DateTime from, DateTime to) async {
    try {
      final snap = await _db
          .collection('requests')
          .where('user_id', isEqualTo: userId)
          .where('company_id', isEqualTo: companyId)
          .where('type', isEqualTo: 'sick')
          .where('status', whereIn: ['approved', 'completed']).get();

      int days = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final start = (data['start_date'] as Timestamp).toDate();
        final end = data['end_date'] != null
            ? (data['end_date'] as Timestamp).toDate()
            : DateTime.now();

        final overlapStart = start.isBefore(from) ? from : start;
        final overlapEnd = end.isAfter(to) ? to : end;

        if (overlapEnd.isAfter(overlapStart)) {
          days += overlapEnd.difference(overlapStart).inDays + 1;
        }
      }
      return days;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final worker = widget.worker;

    final avatarColor = AppColors.avatarColors[
        worker.uid.hashCode.abs() % AppColors.avatarColors.length];

    return Scaffold(
      appBar: AppBar(
        title: Text(worker.fullName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Error banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_errorMessage — neke statistike možda nisu dostupne',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Avatar ──────────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: avatarColor.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            worker.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(worker.fullName,
                          style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _roleColor(worker.role).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _roleLabel(worker.role),
                          style: TextStyle(
                            color: _roleColor(worker.role),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Osnovne informacije ────────────────────────────────────
                _SectionTitle(label: 'Osnovne informacije'),
                const SizedBox(height: 10),
                _InfoCard(children: [
                  _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: worker.email),
                  _Divider(),
                  _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Telefon',
                      value: worker.phone.isEmpty ? '—' : worker.phone),
                  _Divider(),
                  _InfoRow(
                      icon: Icons.cake_outlined,
                      label: 'Datum rođenja',
                      value: worker.birthDate != null
                          ? _dateFmt.format(worker.birthDate!)
                          : '—'),
                ]),

                const SizedBox(height: 24),

                // ─── Radni sati ─────────────────────────────────────────────
                _SectionTitle(label: 'Radni sati'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Ova\nsedmica',
                        value: '${_hoursThisWeek}h',
                        color: AppColors.primary,
                        icon: Icons.today_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Ovaj\nmjesec',
                        value: '${_hoursThisMonth}h',
                        color: AppColors.info,
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Ova\ngodina',
                        value: '${_hoursThisYear}h',
                        color: AppColors.adminColor,
                        icon: Icons.bar_chart_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── Godišnji odmor ─────────────────────────────────────────
                _SectionTitle(label: 'Godišnji odmor'),
                const SizedBox(height: 10),
                _InfoCard(children: [
                  _InfoRow(
                      icon: Icons.beach_access_rounded,
                      label: 'Ukupno dana',
                      value: '$_vacationTotal dana'),
                  _Divider(),
                  _InfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Iskorišćeno',
                      value: '$_vacationUsed dana',
                      valueColor: _vacationUsed > 0 ? AppColors.warning : null),
                  _Divider(),
                  _InfoRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Preostalo',
                      value: '$_vacationRemaining dana',
                      valueColor: AppColors.success),
                  _Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _vacationTotal > 0
                                ? _vacationRemaining / _vacationTotal
                                : 0,
                            backgroundColor: AppColors.error.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.success),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_vacationRemaining od $_vacationTotal dana preostalo',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ─── Bolovanje ──────────────────────────────────────────────
                _SectionTitle(label: 'Bolovanje ${DateTime.now().year}'),
                const SizedBox(height: 10),
                _InfoCard(children: [
                  _InfoRow(
                    icon: Icons.medical_services_outlined,
                    label: 'Dana bolovanja',
                    value: _sickDaysThisYear > 0
                        ? '$_sickDaysThisYear dana'
                        : 'Nije koristio/la',
                    valueColor: _sickDaysThisYear > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.adminColor;
      case UserRole.manager:
        return AppColors.managerColor;
      default:
        return AppColors.workerColor;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Menadžer';
      default:
        return 'Radnik';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textSecondaryLight,
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.dividerDark
          : AppColors.dividerLight,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
