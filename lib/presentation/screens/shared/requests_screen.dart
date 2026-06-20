import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/request_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/company_provider.dart';
import '../../widgets/common/leave_balance_widget.dart';

// ─── ADMIN REQUESTS SCREEN ────────────────────────────────────────────────────
class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requests = context.watch<RequestProvider>().requests;
    final pending = requests.where((r) => r.isPending).toList();
    final others = requests.where((r) => !r.isPending).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zahtjevi', style: theme.textTheme.displayMedium),
                  Text(
                    pending.isEmpty
                        ? 'Nema zahtjeva na čekanju'
                        : '${pending.length} na čekanju',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: pending.isNotEmpty
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: requests.isEmpty
                  ? _EmptyRequests()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (pending.isNotEmpty) ...[
                          _SectionLabel(label: 'Na čekanju'),
                          const SizedBox(height: 8),
                          ...pending.map((r) => _AdminRequestCard(request: r)),
                          const SizedBox(height: 16),
                        ],
                        if (others.isNotEmpty) ...[
                          _SectionLabel(label: 'Istorija'),
                          const SizedBox(height: 8),
                          ...others.map((r) => _AdminRequestCard(request: r)),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WORKER REQUESTS SCREEN ───────────────────────────────────────────────────
class WorkerRequestsScreen extends StatefulWidget {
  const WorkerRequestsScreen({super.key});

  @override
  State<WorkerRequestsScreen> createState() => _WorkerRequestsScreenState();
}

class _WorkerRequestsScreenState extends State<WorkerRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requestProvider = context.watch<RequestProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final requests = requestProvider.requests;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Zahtjevi', style: theme.textTheme.displayMedium),
            ),
            const SizedBox(height: 20),

            // ─── Stanje odmora ────────────────────────────────────────────
            const LeaveBalanceWidget(),

            const SizedBox(height: 16),

            // ─── Novi zahtjev card ────────────────────────────────────────
            _NewRequestCard(
              vacationDaysLeft: user?.vacationDays ?? 0,
              onSubmitVacation: (start, end, reason) async {
                if (user == null) return;
                final success = await requestProvider.requestVacation(
                  userId: user.uid,
                  companyId: user.currentCompanyId!,
                  startDate: start,
                  endDate: end,
                  reason: reason,
                );
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Zahtjev je poslat!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              onSubmitSick: (reason) async {
                if (user == null) return;
                final success = await requestProvider.startSickLeave(
                  userId: user.uid,
                  companyId: user.currentCompanyId!,
                );
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Zahtjev za bolovanje je poslat. Čeka se odobrenje.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // ─── Moji zahtjevi ────────────────────────────────────────────
            if (requests.isNotEmpty) ...[
              Text('Moji zahtjevi', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...requests.map((r) => _WorkerRequestCard(request: r)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── NEW REQUEST CARD (Worker) ────────────────────────────────────────────────
class _NewRequestCard extends StatefulWidget {
  final int vacationDaysLeft;
  final Function(DateTime, DateTime, String?) onSubmitVacation;
  final Function(String?) onSubmitSick;

  const _NewRequestCard({
    required this.vacationDaysLeft,
    required this.onSubmitVacation,
    required this.onSubmitSick,
  });

  @override
  State<_NewRequestCard> createState() => _NewRequestCardState();
}

class _NewRequestCardState extends State<_NewRequestCard> {
  String _selectedType = 'vacation'; // vacation | sick
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  final DateFormat _fmt = DateFormat('dd.MM.yyyy');

  int get _requestedDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedType == 'vacation') {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izaberite datum početka i kraja'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_requestedDays > widget.vacationDaysLeft) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Nemate dovoljno dana odmora (ostalo: ${widget.vacationDaysLeft})'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    if (_selectedType == 'vacation') {
      await widget.onSubmitVacation(
        _startDate!,
        _endDate!,
        _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      setState(() {
        _startDate = null;
        _endDate = null;
        _reasonController.clear();
      });
    } else {
      await widget.onSubmitSick(
        _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      _reasonController.clear();
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Novi zahtjev', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 14),

          // ─── Tip zahtjeva ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'Godišnji odmor',
                  icon: Icons.beach_access_rounded,
                  isSelected: _selectedType == 'vacation',
                  color: AppColors.primary,
                  onTap: () => setState(() => _selectedType = 'vacation'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TypeButton(
                  label: 'Bolovanje',
                  icon: Icons.medical_services_outlined,
                  isSelected: _selectedType == 'sick',
                  color: AppColors.warning,
                  onTap: () => setState(() => _selectedType = 'sick'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ─── Vacation specific ──────────────────────────────────────────
          if (_selectedType == 'vacation') ...[
            // Balance
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Preostalo: ${widget.vacationDaysLeft} dana',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Datumi
            Row(
              children: [
                Expanded(
                  child: _DateBox(
                    label: 'Početak',
                    value: _startDate != null ? _fmt.format(_startDate!) : null,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateBox(
                    label: 'Kraj',
                    value: _endDate != null ? _fmt.format(_endDate!) : null,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),

            if (_startDate != null && _endDate != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Traženih dana: $_requestedDays',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],

          // ─── Sick specific ──────────────────────────────────────────────
          if (_selectedType == 'sick') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bolovanje počinje od danas. Admin mora odobriti zahtjev.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Razlog
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Napomena (opciono)',
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType == 'sick'
                    ? AppColors.warning
                    : AppColors.primary,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_selectedType == 'sick'
                      ? 'Pošalji zahtjev za bolovanje'
                      : 'Pošalji zahtjev'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TYPE BUTTON ─────────────────────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : isDark
                  ? AppColors.inputFillDark
                  : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? color : AppColors.textSecondaryLight),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ADMIN REQUEST CARD ───────────────────────────────────────────────────────
class _AdminRequestCard extends StatefulWidget {
  final RequestModel request;
  const _AdminRequestCard({required this.request});

  @override
  State<_AdminRequestCard> createState() => _AdminRequestCardState();
}

class _AdminRequestCardState extends State<_AdminRequestCard> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    final currentUser = context.read<AuthProvider>().currentUser;
    final success = await context.read<RequestProvider>().approveRequest(
          requestId: widget.request.requestId,
          reviewedBy: currentUser?.uid ?? '',
        );
    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Zahtjev odobren!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reject() async {
    // Otvori dialog za reject note
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Odbij zahtjev'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dodaj napomenu za radnika (opciono):'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Razlog odbijanja...',
              ),
            ),
          ],
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
            child: const Text('Odbij'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    final currentUser = context.read<AuthProvider>().currentUser;
    final success = await context.read<RequestProvider>().rejectRequest(
          requestId: widget.request.requestId,
          reviewedBy: currentUser?.uid ?? '',
          rejectNote: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
    noteController.dispose();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Zahtjev odbijen.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color get _statusColor {
    switch (widget.request.status) {
      case RequestStatus.approved:
        return AppColors.success;
      case RequestStatus.rejected:
        return AppColors.error;
      case RequestStatus.pending:
        return AppColors.warning;
      case RequestStatus.cancelled:
        return AppColors.textSecondaryLight;
      case RequestStatus.completed:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = DateFormat('dd.MM.yyyy');
    final request = widget.request;

    UserModel? worker;
    try {
      final team = context.read<CompanyProvider>().team;
      worker = team.where((m) => m.uid == request.userId).firstOrNull;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (request.isSick
                                ? AppColors.warning
                                : AppColors.primary)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        request.isSick
                            ? Icons.medical_services_outlined
                            : Icons.beach_access_rounded,
                        size: 18,
                        color: request.isSick
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.type.label,
                              style: theme.textTheme.titleLarge),
                          Text(
                            request.endDate != null
                                ? '${fmt.format(request.startDate)} – ${fmt.format(request.endDate!)}'
                                : 'Od ${fmt.format(request.startDate)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.status.label,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                // Worker info
                if (worker != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.inputFillDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.avatarColors[
                                worker.uid.hashCode.abs() %
                                    AppColors.avatarColors.length],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(worker.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(worker.fullName,
                                  style: theme.textTheme.titleLarge),
                              if (worker.phone.isNotEmpty)
                                Text(worker.phone,
                                    style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (request.requestedDays != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Traženih dana: ${request.requestedDays}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                if (request.reason != null && request.reason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Napomena: ${request.reason}',
                      style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),

          // ─── Akcije ─────────────────────────────────────────────────────
          if (request.isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 44),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.error))
                          : const Text('Odbij'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 44),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Odobri'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── WORKER REQUEST CARD ──────────────────────────────────────────────────────
class _WorkerRequestCard extends StatelessWidget {
  final RequestModel request;
  const _WorkerRequestCard({required this.request});

  Color get _statusColor {
    switch (request.status) {
      case RequestStatus.approved:
        return AppColors.success;
      case RequestStatus.rejected:
        return AppColors.error;
      case RequestStatus.pending:
        return AppColors.warning;
      case RequestStatus.cancelled:
        return AppColors.textSecondaryLight;
      case RequestStatus.completed:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = DateFormat('dd.MM.yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (request.isSick ? AppColors.warning : AppColors.primary)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  request.isSick
                      ? Icons.medical_services_outlined
                      : Icons.beach_access_rounded,
                  size: 18,
                  color: request.isSick ? AppColors.warning : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.type.label, style: theme.textTheme.titleLarge),
                    Text(
                      request.endDate != null
                          ? '${fmt.format(request.startDate)} – ${fmt.format(request.endDate!)}'
                          : 'Od ${fmt.format(request.startDate)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.label,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          if (request.requestedDays != null) ...[
            const SizedBox(height: 6),
            Text(
              'Traženih dana: ${request.requestedDays}',
              style: theme.textTheme.bodySmall,
            ),
          ],

          // Reject note od admina
          if (request.status == RequestStatus.rejected &&
              request.rejectNote != null &&
              request.rejectNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Napomena admina: ${request.rejectNote}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── DATE BOX ─────────────────────────────────────────────────────────────────
class _DateBox extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateBox({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.inputFillDark : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14,
                    color: value != null
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)),
                const SizedBox(width: 6),
                Text(
                  value ?? 'Izaberi',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: value != null ? AppColors.primary : null,
                    fontWeight:
                        value != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION LABEL ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
    );
  }
}

// ─── EMPTY REQUESTS ───────────────────────────────────────────────────────────
class _EmptyRequests extends StatelessWidget {
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
            child: const Icon(Icons.inbox_rounded,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Nema zahtjeva', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Novi zahtjevi će se pojaviti ovde',
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
