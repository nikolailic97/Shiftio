import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class WorkerReportRow {
  final String name;
  final String surname;
  final DateTime? birthDate;
  final int totalWorkDays;
  final double totalWorkHours;
  final int sickDays;
  final int vacationUsed;
  final int vacationRemaining;

  const WorkerReportRow({
    required this.name,
    required this.surname,
    this.birthDate,
    required this.totalWorkDays,
    required this.totalWorkHours,
    required this.sickDays,
    required this.vacationUsed,
    required this.vacationRemaining,
  });
}

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // ─── GENERISI PODATKE ZA IZVESTAJ ─────────────────────────────────────────

  Future<List<WorkerReportRow>> generateReportData({
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    final workers = await _firestoreService.getTeamMembers(companyId);
    final List<WorkerReportRow> rows = [];

    for (final worker in workers) {
      // Ukupni sati rada — sad sa company_id filterom
      final totalMinutes = await _firestoreService.getTotalMinutesForWorker(
        workerId: worker.uid,
        companyId: companyId,
        from: from,
        to: to,
      );

      // Dani bolovanja — sad sa company_id filterom
      final sickDays = await _getSickDays(
        userId: worker.uid,
        companyId: companyId,
        from: from,
        to: to,
      );

      // Iskorisceni godisnji odmor — sad sa company_id filterom
      final vacationUsed = await _getVacationUsed(
        userId: worker.uid,
        companyId: companyId,
        from: from,
        to: to,
      );

      // Ukupno radnih dana — sad sa company_id filterom
      final workDays = await _getWorkDays(
        workerId: worker.uid,
        companyId: companyId,
        from: from,
        to: to,
      );

      rows.add(WorkerReportRow(
        name: worker.name,
        surname: worker.surname,
        birthDate: worker.birthDate,
        totalWorkDays: workDays,
        totalWorkHours: totalMinutes / 60.0,
        sickDays: sickDays,
        vacationUsed: vacationUsed,
        vacationRemaining: worker.vacationDays,
      ));
    }

    rows.sort((a, b) {
      final cmp = a.surname.compareTo(b.surname);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    return rows;
  }

  // ─── EXPORT KAO EXCEL (.xlsx) ─────────────────────────────────────────────

  Future<File> exportToExcel({
    required String companyName,
    required List<WorkerReportRow> rows,
    required DateTime from,
    required DateTime to,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Izvestaj'];
    excel.delete('Sheet1');

    final dateFmt = DateFormat('dd.MM.yyyy');
    final periodStr = '${dateFmt.format(from)} – ${dateFmt.format(to)}';

    // Naslov
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('H1'),
    );
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('Shiftio — Izvestaj o radu');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#2A6FDB'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Firma i period
    sheet.merge(
      CellIndex.indexByString('A2'),
      CellIndex.indexByString('H2'),
    );
    final subTitleCell = sheet.cell(CellIndex.indexByString('A2'));
    subTitleCell.value = TextCellValue('$companyName | Period: $periodStr');
    subTitleCell.cellStyle = CellStyle(
      bold: false,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#EBF3FF'),
    );

    // Datum generisanja
    sheet.merge(
      CellIndex.indexByString('A3'),
      CellIndex.indexByString('H3'),
    );
    final dateCell = sheet.cell(CellIndex.indexByString('A3'));
    dateCell.value =
        TextCellValue('Generisano: ${dateFmt.format(DateTime.now())}');
    dateCell.cellStyle = CellStyle(
      fontSize: 9,
      horizontalAlign: HorizontalAlign.Right,
    );

    // Kolone
    final headers = [
      'Ime',
      'Prezime',
      'Datum rodjenja',
      'Radnih dana',
      'Radnih sati',
      'Dana bolovanja',
      'Godisnji (iskorisceno)',
      'Godisnji (preostalo)',
    ];

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1A4FA8'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    for (int i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Podaci
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowIndex = i + 4;
      final isEven = i % 2 == 0;

      final bgColor = isEven
          ? ExcelColor.fromHexString('#F4F6FA')
          : ExcelColor.fromHexString('#FFFFFF');

      final dataStyle = CellStyle(
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: bgColor,
      );

      final leftStyle = CellStyle(
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Left,
        backgroundColorHex: bgColor,
      );

      final nameCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      nameCell.value = TextCellValue(row.name);
      nameCell.cellStyle = leftStyle;

      final surnameCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      surnameCell.value = TextCellValue(row.surname);
      surnameCell.cellStyle = leftStyle;

      final birthCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      birthCell.value = TextCellValue(
        row.birthDate != null ? dateFmt.format(row.birthDate!) : '—',
      );
      birthCell.cellStyle = dataStyle;

      final daysCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      daysCell.value = IntCellValue(row.totalWorkDays);
      daysCell.cellStyle = dataStyle;

      final hoursCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      hoursCell.value = DoubleCellValue(
        double.parse(row.totalWorkHours.toStringAsFixed(1)),
      );
      hoursCell.cellStyle = dataStyle;

      final sickCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      sickCell.value = IntCellValue(row.sickDays);
      sickCell.cellStyle = dataStyle;

      final vacUsedCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
      vacUsedCell.value = IntCellValue(row.vacationUsed);
      vacUsedCell.cellStyle = dataStyle;

      final vacRemCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex));
      vacRemCell.value = IntCellValue(row.vacationRemaining);
      vacRemCell.cellStyle = dataStyle;
    }

    // Sirine kolona
    sheet.setColumnWidth(0, 16);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 22);
    sheet.setColumnWidth(7, 20);

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'Shiftio_Izvestaj_${DateFormat('yyyy-MM-dd').format(from)}_${DateFormat('yyyy-MM-dd').format(to)}.xlsx';
    final file = File('${dir.path}/$fileName');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Greska pri generisanju Excel fajla');

    await file.writeAsBytes(bytes);
    return file;
  }

  // ─── EXPORT KAO CSV ───────────────────────────────────────────────────────

  Future<File> exportToCsv({
    required String companyName,
    required List<WorkerReportRow> rows,
    required DateTime from,
    required DateTime to,
  }) async {
    final dateFmt = DateFormat('dd.MM.yyyy');
    final buffer = StringBuffer();

    buffer.writeln(
        'Ime,Prezime,Datum rodjenja,Radnih dana,Radnih sati,Dana bolovanja,Godisnji (iskorisceno),Godisnji (preostalo)');

    for (final row in rows) {
      final birth = row.birthDate != null ? dateFmt.format(row.birthDate!) : '';
      final hours = row.totalWorkHours.toStringAsFixed(1);
      buffer.writeln(
        '${row.name},${row.surname},$birth,${row.totalWorkDays},$hours,${row.sickDays},${row.vacationUsed},${row.vacationRemaining}',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'Shiftio_Izvestaj_${DateFormat('yyyy-MM-dd').format(from)}_${DateFormat('yyyy-MM-dd').format(to)}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());
    return file;
  }

  // ─── POMOCNE METODE ───────────────────────────────────────────────────────

  Future<int> _getSickDays({
    required String userId,
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) async {
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
  }

  Future<int> _getVacationUsed({
    required String userId,
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('requests')
        .where('user_id', isEqualTo: userId)
        .where('company_id', isEqualTo: companyId)
        .where('type', isEqualTo: 'vacation')
        .where('status', isEqualTo: 'approved')
        .get();

    int days = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final requestedDays = data['requested_days'] as int? ?? 0;
      final start = (data['start_date'] as Timestamp).toDate();

      if (!start.isBefore(from) && !start.isAfter(to)) {
        days += requestedDays;
      }
    }
    return days;
  }

  Future<int> _getWorkDays({
    required String workerId,
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('shifts')
        .where('worker_id', isEqualTo: workerId)
        .where('company_id', isEqualTo: companyId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();

    final uniqueDays = <String>{};
    for (final doc in snap.docs) {
      final date = (doc.data()['date'] as Timestamp).toDate();
      uniqueDays.add(DateFormat('yyyy-MM-dd').format(date));
    }
    return uniqueDays.length;
  }
}
