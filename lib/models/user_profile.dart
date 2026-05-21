import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String role;
  final String companyName;
  final String companyLegalName;
  final String companyTaxId;
  final String companyPhone;
  final String companyEmail;
  final String entityType;
  final String companyDocumentType;
  final String identityVerificationStatus;
  final String registrationStage;
  final String buyerName;
  final String buyerRoleTitle;
  final String buyerDocument;
  final String buyerPhone;
  final bool profileCompleted;
  final DateTime? profileCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.companyName,
    required this.companyLegalName,
    required this.companyTaxId,
    required this.companyPhone,
    required this.companyEmail,
    required this.entityType,
    required this.companyDocumentType,
    required this.identityVerificationStatus,
    required this.registrationStage,
    required this.buyerName,
    required this.buyerRoleTitle,
    required this.buyerDocument,
    required this.buyerPhone,
    required this.profileCompleted,
    this.profileCompletedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.empty({
    required String id,
    required String email,
    String role = '',
  }) {
    return UserProfile(
      id: id,
      email: email,
      role: role,
      companyName: '',
      companyLegalName: '',
      companyTaxId: '',
      companyPhone: '',
      companyEmail: email,
      entityType: 'legal',
      companyDocumentType: 'cnpj',
      identityVerificationStatus: 'pending',
      registrationStage: 'seeded',
      buyerName: '',
      buyerRoleTitle: '',
      buyerDocument: '',
      buyerPhone: '',
      profileCompleted: false,
      profileCompletedAt: null,
    );
  }

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final normalizedRole = _normalizeRole((data['role'] ?? '').toString());
    final completedAt = _readDate(data['profileCompletedAt']);
    final completed = data['profileCompleted'] == true;
    final companyName = (data['companyName'] ?? '').toString();
    final companyLegalName = (data['companyLegalName'] ?? '').toString();
    final companyTaxId = (data['companyTaxId'] ?? '').toString();
    final companyPhone = (data['companyPhone'] ?? '').toString();
    final companyEmail = (data['companyEmail'] ?? '').toString();
    final buyerName = (data['buyerName'] ?? '').toString();
    final buyerRoleTitle = (data['buyerRoleTitle'] ?? '').toString();
    final buyerDocument = (data['buyerDocument'] ?? '').toString();
    final buyerPhone = (data['buyerPhone'] ?? '').toString();
    final entityType = _normalizeEntityType(
      (data['entityType'] ?? '').toString(),
    );
    final documentType = _normalizeDocumentType(
      (data['companyDocumentType'] ?? '').toString(),
      fallbackTaxId: companyTaxId,
    );
    final hasIdentityFallback =
        companyName.trim().isNotEmpty &&
        companyLegalName.trim().isNotEmpty &&
        companyTaxId.trim().isNotEmpty &&
        companyPhone.trim().isNotEmpty &&
        companyEmail.trim().isNotEmpty &&
        buyerName.trim().isNotEmpty &&
        buyerRoleTitle.trim().isNotEmpty &&
        buyerDocument.trim().isNotEmpty &&
        buyerPhone.trim().isNotEmpty;

    return UserProfile(
      id: doc.id,
      email: (data['email'] ?? '').toString(),
      role: normalizedRole,
      companyName: companyName,
      companyLegalName: companyLegalName,
      companyTaxId: companyTaxId,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      entityType: entityType,
      companyDocumentType: documentType,
      identityVerificationStatus: _normalizeIdentityVerificationStatus(
        (data['identityVerificationStatus'] ?? '').toString(),
        completed: completed,
        hasIdentityFallback: hasIdentityFallback,
      ),
      registrationStage: _normalizeRegistrationStage(
        (data['registrationStage'] ?? '').toString(),
        completed: completed,
      ),
      buyerName: buyerName,
      buyerRoleTitle: buyerRoleTitle,
      buyerDocument: buyerDocument,
      buyerPhone: buyerPhone,
      profileCompleted: completed,
      profileCompletedAt: completedAt,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  bool get isSupplier => role.trim().toLowerCase() == 'supplier';

  bool get isBuyer => role.trim().toLowerCase() == 'buyer';

  bool get isIndividual => entityType == 'individual';

  bool get isLegalEntity => entityType == 'legal';

  bool get identityVerified => identityVerificationStatus == 'verified';

  bool get hasRequiredIdentity =>
      role.trim().isNotEmpty &&
      companyName.trim().isNotEmpty &&
      companyLegalName.trim().isNotEmpty &&
      companyTaxId.trim().isNotEmpty &&
      companyPhone.trim().isNotEmpty &&
      companyEmail.trim().isNotEmpty &&
      buyerName.trim().isNotEmpty &&
      buyerRoleTitle.trim().isNotEmpty &&
      buyerDocument.trim().isNotEmpty &&
      buyerPhone.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'companyName': companyName,
      'companyLegalName': companyLegalName,
      'companyTaxId': companyTaxId,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
      'entityType': entityType,
      'companyDocumentType': companyDocumentType,
      'identityVerificationStatus': identityVerificationStatus,
      'registrationStage': registrationStage,
      'buyerName': buyerName,
      'buyerRoleTitle': buyerRoleTitle,
      'buyerDocument': buyerDocument,
      'buyerPhone': buyerPhone,
      'profileCompleted': profileCompleted,
      'profileCompletedAt': profileCompletedAt == null
          ? null
          : Timestamp.fromDate(profileCompletedAt!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();

    if (normalized == 'supplier' || normalized == 'fornecedor') {
      return 'supplier';
    }

    return 'buyer';
  }

  static String _normalizeEntityType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'individual' || normalized == 'pf') {
      return 'individual';
    }
    return 'legal';
  }

  static String _normalizeDocumentType(
    String value, {
    required String fallbackTaxId,
  }) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'cpf' || normalized == 'cnpj') {
      return normalized;
    }

    final digits = fallbackTaxId.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return 'cpf';
    }
    return 'cnpj';
  }

  static String _normalizeIdentityVerificationStatus(
    String value, {
    required bool completed,
    required bool hasIdentityFallback,
  }) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'verified' || normalized == 'rejected') {
      return normalized;
    }
    return completed && hasIdentityFallback ? 'verified' : 'pending';
  }

  static String _normalizeRegistrationStage(
    String value, {
    required bool completed,
  }) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'seeded' ||
        normalized == 'profile_completed' ||
        normalized == 'active') {
      return normalized;
    }
    return completed ? 'active' : 'seeded';
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
