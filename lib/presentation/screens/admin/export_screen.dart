import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/report_service.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ReportService _reportService = ReportService();

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _exportFormat = 'xlsx'; // 'xlsx' ili 'csv'

  bool _isLoading = false;
  bool _isPreviewLoading = false;
  List<WorkerReportRow>? _previewData;
  File? _generatedFile;

  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
        } else {
          _toDate = picked;
        }
        _previewData = null;
        _generatedFile = null;
      });
    }
  }

  Future<void> _loadPreview() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.currentCompanyId == null) return;

    setState(() => _isPreviewLoading = true);

    try {
      final data = await _reportService.generateReportData(
        companyId: user!.currentCompanyId!,
        from: _fromDate,
        to: _toDate,
      );
      setState(() {
        _previewData = data;
        _isPreviewLoading = false;
      });
    } catch (e) {
      setState(() => _isPreviewLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Greška pri učitavanju podataka'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateExport() async {
    final user = context.read<AuthProvider>().currentUser;
    final company = context.read<CompanyProvider>().company;
    if (user?.currentCompanyId == null) return;

    setState(() => _isLoading = true);

    try {
      final data = _previewData ??
          await _reportService.generateReportData(
            companyId: user!.currentCompanyId!,
            from: _fromDate,
            to: _toDate,
          );

      File file;
      if (_exportFormat == 'xlsx') {
        file = await _reportService.exportToExcel(
          companyName: company?.name ?? 'Shiftio',
          rows: data,
          from: _fromDate,
          to: _toDate,
        );
      } else {
        file = await _reportService.exportToCsv(
          companyName: company?.name ?? 'Shiftio',
          rows: data,
          from: _fromDate,
          to: _toDate,
        );
      }

      setState(() {
        _generatedFile = file;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fajl generisan: ${file.path.split('/').last}'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Otvori',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    if (_generatedFile == null) return;
    await Share.shareXFiles(
      [XFile(_generatedFile!.path)],
      subject: 'Shiftio Izvještaj',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export podataka'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Period ──────────────────────────────────────────────────────────
          Text('Period izvještaja', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: 'Od',
                  value: _dateFmt.format(_fromDate),
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateBox(
                  label: 'Do',
                  value: _dateFmt.format(_toDate),
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Format ──────────────────────────────────────────────────────────
          Text('Format fajla', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _FormatCard(
                  icon: Icons.table_chart_rounded,
                  label: 'Excel (.xlsx)',
                  subtitle: 'Formatiran, sa bojama',
                  isSelected: _exportFormat == 'xlsx',
                  color: AppColors.success,
                  onTap: () => setState(() => _exportFormat = 'xlsx'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormatCard(
                  icon: Icons.description_rounded,
                  label: 'CSV',
                  subtitle: 'Za import u Excel/Sheets',
                  isSelected: _exportFormat == 'csv',
                  color: AppColors.info,
                  onTap: () => setState(() => _exportFormat = 'csv'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Preview dugme ────────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: _isPreviewLoading ? null : _loadPreview,
            icon: _isPreviewLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.preview_rounded, size: 18),
            label:
                Text(_isPreviewLoading ? 'Učitavanje...' : 'Prikaži pregled'),
          ),

          // ─── Preview tabela ───────────────────────────────────────────────────
          if (_previewData != null) ...[
            const SizedBox(height: 20),
            Text(
              'Pregled — ${_previewData!.length} radnika',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            _PreviewTable(rows: _previewData!),
          ],

          const SizedBox(height: 24),

          // ─── Export dugme ─────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateExport,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(
              _isLoading
                  ? 'Generisanje...'
                  : 'Generiši ${_exportFormat.toUpperCase()}',
            ),
          ),

          // ─── Share dugme ──────────────────────────────────────────────────────
          if (_generatedFile != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _shareFile,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Podijeli fajl'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => OpenFilex.open(_generatedFile!.path),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Otvori fajl'),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Date Box ─────────────────────────────────────────────────────────────────
class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
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

// ─── Format Card ──────────────────────────────────────────────────────────────
class _FormatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FormatCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.08)
              : (isDark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: isSelected ? color : AppColors.textSecondaryLight,
                size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isSelected ? color : null,
              ),
            ),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ─── Preview Table ────────────────────────────────────────────────────────────
class _PreviewTable extends StatelessWidget {
  final List<WorkerReportRow> rows;

  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fmt = DateFormat('dd.MM.yyyy');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.primary.withOpacity(0.1),
            ),
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Ime i prezime')),
              DataColumn(label: Text('Rođendan')),
              DataColumn(label: Text('Dana')),
              DataColumn(label: Text('Sati')),
              DataColumn(label: Text('Bolovanje')),
              DataColumn(label: Text('God. (isk.)')),
              DataColumn(label: Text('God. (pre.)')),
            ],
            rows: rows.map((row) {
              return DataRow(cells: [
                DataCell(Text('${row.name} ${row.surname}')),
                DataCell(Text(
                  row.birthDate != null ? fmt.format(row.birthDate!) : '—',
                )),
                DataCell(Text('${row.totalWorkDays}')),
                DataCell(Text(row.totalWorkHours.toStringAsFixed(1))),
                DataCell(Text('${row.sickDays}')),
                DataCell(Text('${row.vacationUsed}')),
                DataCell(Text('${row.vacationRemaining}')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
