import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/shift_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../providers/schedule_provider.dart';

class AdminShiftDetailScreen extends StatefulWidget {
  final ShiftModel shift;
  final UserModel? worker;

  const AdminShiftDetailScreen({
    super.key,
    required this.shift,
    this.worker,
  });

  @override
  State<AdminShiftDetailScreen> createState() => _AdminShiftDetailScreenState();
}

class _AdminShiftDetailScreenState extends State<AdminShiftDetailScreen> {
  final _noteController = TextEditingController();
  bool _isEditingNote = false;
  bool _isSavingNote = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.shift.noteAdmin ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() => _isSavingNote = true);
    try {
      await _firestoreService.updateShift(widget.shift.shiftId, {
        'note_admin': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      });
      setState(() {
        _isEditingNote = false;
        _isSavingNote = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Napomena sačuvana'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingNote = false);
    }
  }

  Future<void> _deleteShift() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obriši smenu'),
        content: Text(
          'Obrisati smenu ${widget.shift.timeRangeFormatted}?',
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
      await context.read<ScheduleProvider>().deleteShift(widget.shift.shiftId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shift = widget.shift;
    final worker = widget.worker;
    final fmt = DateFormat('dd.MM.yyyy');

    final avatarColor = worker != null
        ? AppColors.avatarColors[
            worker.uid.hashCode.abs() % AppColors.avatarColors.length]
        : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji smene'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: _deleteShift,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Vreme smene ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.timeRangeFormatted,
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shift.durationFormatted} • ${fmt.format(shift.date)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Radnik ───────────────────────────────────────────────────────
          if (worker != null) ...[
            Text('Radnik', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        worker.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(worker.fullName,
                            style: theme.textTheme.titleLarge),
                        Text(worker.email, style: theme.textTheme.bodySmall),
                        Text(
                          worker.role == UserRole.manager
                              ? 'Menadžer'
                              : 'Radnik',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─── Komentar radnika ─────────────────────────────────────────────
          Row(
            children: [
              Text('Komentar radnika', style: theme.textTheme.headlineSmall),
              const SizedBox(width: 8),
              if (shift.hasComment)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Novi komentar',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: shift.hasComment
                  ? AppColors.warning.withOpacity(0.08)
                  : isDark
                      ? AppColors.cardDark
                      : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(14),
              border: shift.hasComment
                  ? Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 1.5,
                    )
                  : null,
            ),
            child:
                shift.workerComment != null && shift.workerComment!.isNotEmpty
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shift.workerComment!,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Radnik nije ostavio komentar',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
          ),

          const SizedBox(height: 20),

          // ─── Admin napomena ───────────────────────────────────────────────
          Row(
            children: [
              Text('Vaša napomena', style: theme.textTheme.headlineSmall),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingNote = !_isEditingNote;
                    if (!_isEditingNote) {
                      _noteController.text = shift.noteAdmin ?? '';
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  _isEditingNote ? 'Otkaži' : 'Uredi',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isEditingNote) ...[
            TextField(
              controller: _noteController,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Dodaj napomenu za radnika...',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isSavingNote ? null : _saveNote,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
              ),
              child: _isSavingNote
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Sačuvaj napomenu'),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: shift.noteAdmin != null && shift.noteAdmin!.isNotEmpty
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(shift.noteAdmin!,
                              style: theme.textTheme.bodyLarge),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 10),
                        Text('Nema napomene',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
