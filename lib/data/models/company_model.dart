import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String companyId;
  final String ownerId;
  final String name;
  final String inviteCode; // 15-char: SHFT-XXX-XXX-XXX
  final DateTime createdAt;
  final String? logoUrl;

  const CompanyModel({
    required this.companyId,
    required this.ownerId,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    this.logoUrl,
  });

  factory CompanyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyModel(
      companyId: doc.id,
      ownerId: data['owner_id'] ?? '',
      name: data['name'] ?? '',
      inviteCode: data['invite_code'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      logoUrl: data['logo_url'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'owner_id': ownerId,
      'name': name,
      'invite_code': inviteCode,
      'created_at': Timestamp.fromDate(createdAt),
      'logo_url': logoUrl,
    };
  }

  CompanyModel copyWith({
    String? name,
    String? logoUrl,
  }) {
    return CompanyModel(
      companyId: companyId,
      ownerId: ownerId,
      name: name ?? this.name,
      inviteCode: inviteCode,
      createdAt: createdAt,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
