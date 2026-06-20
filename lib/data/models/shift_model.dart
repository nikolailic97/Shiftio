import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftModel {
  final String shiftId;
  final String companyId;
  final String workerId;
  final String? batchId; // za grupno brisanje
  final DateTime startTime;
  final int durationMinutes; // trajanje u minutima
  final DateTime date;
  final String? noteAdmin;
  final String? workerComment;
  final bool hasComment;
  final DateTime timestamp;
  final bool notificationSent;

  const ShiftModel({
    required this.shiftId,
    required this.companyId,
    required this.workerId,
    this.batchId,
    required this.startTime,
    required this.durationMinutes,
    required this.date,
    this.noteAdmin,
    this.workerComment,
    this.hasComment = false,
    required this.timestamp,
    this.notificationSent = false,
  });

  /// Kraj smene izračunat automatski
  DateTime get endTime =>
      startTime.add(Duration(minutes: durationMinutes));

  /// Formatiran prikaz trajanja (npr. "8h 30min" ili "8h")
  String get durationFormatted {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  /// Formatiran prikaz vremena (npr. "07:00 – 15:00")
  String get timeRangeFormatted {
    String _pad(int n) => n.toString().padLeft(2, '0');
    final startStr =
        '${_pad(startTime.hour)}:${_pad(startTime.minute)}';
    final endStr =
        '${_pad(endTime.hour)}:${_pad(endTime.minute)}';
    return '$startStr – $endStr';
  }

  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftModel(
      shiftId: doc.id,
      companyId: data['company_id'] ?? '',
      workerId: data['worker_id'] ?? '',
      batchId: data['batch_id'],
      startTime: (data['start_time'] as Timestamp).toDate(),
      durationMinutes: data['duration_minutes'] ?? 0,
      date: (data['date'] as Timestamp).toDate(),
      noteAdmin: data['note_admin'],
      workerComment: data['worker_comment'],
      hasComment: data['has_comment'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationSent: data['notification_sent'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'worker_id': workerId,
      'batch_id': batchId,
      'start_time': Timestamp.fromDate(startTime),
      'duration_minutes': durationMinutes,
      'date': Timestamp.fromDate(date),
      'note_admin': noteAdmin,
      'worker_comment': workerComment,
      'has_comment': hasComment,
      'timestamp': Timestamp.fromDate(timestamp),
      'notification_sent': notificationSent,
    };
  }

  ShiftModel copyWith({
    String? noteAdmin,
    String? workerComment,
    bool? hasComment,
    int? durationMinutes,
    DateTime? startTime,
  }) {
    return ShiftModel(
      shiftId: shiftId,
      companyId: companyId,
      workerId: workerId,
      batchId: batchId,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date,
      noteAdmin: noteAdmin ?? this.noteAdmin,
      workerComment: workerComment ?? this.workerComment,
      hasComment: hasComment ?? this.hasComment,
      timestamp: timestamp,
      notificationSent: notificationSent,
    );
  }
}