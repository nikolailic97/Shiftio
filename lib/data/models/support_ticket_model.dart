import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus { newTicket, read }

class SupportTicketModel {
  final String ticketId;
  final String userId;
  final String message;
  final DateTime timestamp;
  final TicketStatus status;

  const SupportTicketModel({
    required this.ticketId,
    required this.userId,
    required this.message,
    required this.timestamp,
    this.status = TicketStatus.newTicket,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status == TicketStatus.newTicket ? 'new' : 'read',
    };
  }

  factory SupportTicketModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicketModel(
      ticketId: doc.id,
      userId: data['user_id'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status:
          data['status'] == 'read' ? TicketStatus.read : TicketStatus.newTicket,
    );
  }
}
