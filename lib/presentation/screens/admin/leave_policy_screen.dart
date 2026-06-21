import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../../data/services/leave_policy_service.dart';
import '../../providers/auth_provider.dart';

class LeavePolicyScreen extends StatefulWidget {
  const LeavePolicyScreen({super.key});

  @override
  State<LeavePolicyScreen> createState() => _LeavePolicyScreenState();
}

class _LeavePolicyScreenState extends State<LeavePolicyScreen> {
  final LeavePolicyService _service = LeavePolicyService();
  final _uuid = const Uuid();

  LeavePolicyModel? _policy;
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _monthNames = [
    'Januar',
    'Februar',
    'Mart',
    'April',
    'Maj',
    'Jun',
    'Jul',
    'Avgust',
    'Septembar',
    'Oktobar',
    'Novembar',
    'Decembar',
  ];

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.currentCompanyId == null) return;

    setState(() => _isLoading = true);
    try {
      final policy = await _service.getPolicy(user!.currentCompanyId!);
      setState(() {
        _policy = policy;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePolicy() async {
    if (_policy == null) return;
    setState(() => _isSaving = true);
    try {
      await _service.savePolicy(_policy!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Politika odmora sačuvana!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Greška pri čuvanju'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  void _updateLeaveType(int index, LeaveType updated) {
    if (_policy == null) return;
    final types = List<LeaveType>.from(_policy!.leaveTypes);
    types[index] = updated;
    setState(() {
      _policy = _policy!.copyWith(leaveTypes: types);
    });
  }

  void _addLeaveType() {
    if (_policy == null) return;
    final newType = LeaveType(
      id: _uuid.v4(),
      name: 'Novi tip odmora',
      daysPerYear: 5,
      carriesOver: false,
      requiresApproval: true,
    );
    setState(() {
      _policy = _policy!.copyWith(
        leaveTypes: [..._policy!.leaveTypes, newType],
      );
    });
  }

  void _removeLeaveType(int index) {
    if (_policy == null) return;
    final types = List<LeaveType>.from(_policy!.leaveTypes);

    // Ne dozvoli brisanje standardnih tipova
    final type = types[index];
    if (['vacation', 'sick', 'slava'].contains(type.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standardni tipovi odmora se ne mogu obrisati'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    types.removeAt(index);
    setState(() {
      _policy = _policy!.copyWith(leaveTypes: types);
    });
  }

  void _updateResetDate(int month, int day) {
    if (_policy == null) return;
    setState(() {
      _policy = _policy!.copyWith(resetMonth: month, resetDay: day);
    });
  }

  int _daysInMonth(int month) {
    // Koristimo neprestupnu godinu kao referencu (29.2 retko relevantno
    // za reset datum, a izbegavamo komplikaciju sa prestupnim godinama)
    const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysPerMonth[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Politika odmora'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePolicy,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : const Text(
                    'Sačuvaj',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _policy == null
              ? const Center(child: Text('Greška pri učitavanju'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.info, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ovdje postavljate kvote odmora za vašu firmu. '
                              'Radnici vide ove kvote pri podnošenju zahtjeva.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Reset datum ────────────────────────────────────────
                    Text('Obnavljanje kvota',
                        style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Datum kada se svim radnicima ponovo dodeljuje puna '
                      'kvota odmora (npr. 1. mart svake godine).',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_repeat_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _policy!.resetDay
                                  .clamp(1, _daysInMonth(_policy!.resetMonth)),
                              decoration: const InputDecoration(
                                labelText: 'Dan',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              items: List.generate(
                                _daysInMonth(_policy!.resetMonth),
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('${i + 1}.'),
                                ),
                              ),
                              onChanged: (day) {
                                if (day != null) {
                                  _updateResetDate(_policy!.resetMonth, day);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: _policy!.resetMonth,
                              decoration: const InputDecoration(
                                labelText: 'Mesec',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_monthNames[i]),
                                ),
                              ),
                              onChanged: (month) {
                                if (month != null) {
                                  // Ako je trenutni dan veći od broja dana
                                  // u novom mesecu, spusti na poslednji
                                  // validan dan tog meseca.
                                  final maxDay = _daysInMonth(month);
                                  final newDay = _policy!.resetDay > maxDay
                                      ? maxDay
                                      : _policy!.resetDay;
                                  _updateResetDate(month, newDay);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('Tipovi odmora',
                        style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 12),

                    // Leave types
                    ..._policy!.leaveTypes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final type = entry.value;
                      final isStandard =
                          ['vacation', 'sick', 'slava'].contains(type.id);

                      return _LeaveTypeCard(
                        leaveType: type,
                        isStandard: isStandard,
                        onUpdate: (updated) => _updateLeaveType(index, updated),
                        onDelete: () => _removeLeaveType(index),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Dodaj novi tip
                    OutlinedButton.icon(
                      onPressed: _addLeaveType,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Dodaj tip odmora'),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
    );
  }
}

// ─── Leave Type Card ──────────────────────────────────────────────────────────

class _LeaveTypeCard extends StatefulWidget {
  final LeaveType leaveType;
  final bool isStandard;
  final ValueChanged<LeaveType> onUpdate;
  final VoidCallback onDelete;

  const _LeaveTypeCard({
    required this.leaveType,
    required this.isStandard,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_LeaveTypeCard> createState() => _LeaveTypeCardState();
}

class _LeaveTypeCardState extends State<_LeaveTypeCard> {
  late TextEditingController _nameController;
  late int _days;
  late bool _carriesOver;
  late bool _requiresApproval;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.leaveType.name);
    _days = widget.leaveType.daysPerYear;
    _carriesOver = widget.leaveType.carriesOver;
    _requiresApproval = widget.leaveType.requiresApproval;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _notifyUpdate() {
    widget.onUpdate(widget.leaveType.copyWith(
      name: _nameController.text,
      daysPerYear: _days,
      carriesOver: _carriesOver,
      requiresApproval: _requiresApproval,
    ));
  }

  Color get _typeColor {
    switch (widget.leaveType.id) {
      case 'vacation':
        return AppColors.primary;
      case 'sick':
        return AppColors.warning;
      case 'slava':
        return AppColors.adminColor;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _typeColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Naziv
              Expanded(
                child: widget.isStandard
                    ? Text(widget.leaveType.name,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: _typeColor))
                    : TextField(
                        controller: _nameController,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: _typeColor),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _notifyUpdate(),
                      ),
              ),
              if (!widget.isStandard)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Dana po godini
          Row(
            children: [
              Text('Dana godišnje:', style: theme.textTheme.bodyMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed: _days > 0
                    ? () {
                        setState(() => _days--);
                        _notifyUpdate();
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppColors.primary,
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '$_days',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: _typeColor),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: () {
                  setState(() => _days++);
                  _notifyUpdate();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppColors.primary,
              ),
            ],
          ),

          const Divider(height: 20),

          // Switches
          _SwitchRow(
            label: 'Prenosi se u sljedeću godinu',
            value: _carriesOver,
            onChanged: (v) {
              setState(() => _carriesOver = v);
              _notifyUpdate();
            },
          ),
          const SizedBox(height: 8),
          _SwitchRow(
            label: 'Zahtijeva odobrenje admina',
            value: _requiresApproval,
            onChanged: (v) {
              setState(() => _requiresApproval = v);
              _notifyUpdate();
            },
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
