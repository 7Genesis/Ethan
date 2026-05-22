import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:projeto_ethan/core/validators/br_documents.dart';
import 'package:projeto_ethan/models/user_profile.dart';

class UserRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> ensureUserProfileDocument({String? roleHint}) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final userRef = firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();
    final docExists = doc.exists;
    _log(
      '[ensureUserProfileDocument] uid=${user.uid} doc.exists=$docExists roleHint=${_normalizeRole(roleHint)}',
    );

    if (docExists) {
      return;
    }

    final role = _normalizeRole(roleHint);
    final now = Timestamp.now();

    final seedPayload = {
      'email': user.email ?? '',
      'role': role,
      'companyName': '',
      'companyLegalName': '',
      'companyTaxId': '',
      'companyPhone': '',
      'companyEmail': user.email ?? '',
      'entityType': 'legal',
      'companyDocumentType': 'cnpj',
      'identityVerificationStatus': 'pending',
      'registrationStage': 'seeded',
      'buyerName': '',
      'buyerRoleTitle': '',
      'buyerDocument': '',
      'buyerPhone': '',
      'profileCompleted': false,
      'profileCompletedAt': null,
      'createdAt': now,
      'updatedAt': now,
    };

    await firestore.runTransaction((transaction) async {
      final latest = await transaction.get(userRef);
      if (latest.exists) {
        _log(
          '[ensureUserProfileDocument] uid=${user.uid} status=already-exists skip-create',
        );
        return;
      }
      transaction.set(userRef, seedPayload);
    });
  }

  Future<void> saveCurrentUserProfile(UserProfile profile) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final userRef = firestore.collection('users').doc(user.uid);
    final currentDoc = await userRef.get();
    final currentDocData = currentDoc.data();

    final now = DateTime.now();
    final current = await getCurrentUserProfile();
    final normalizedRole = _normalizeRole(profile.role);
    final normalizedEntityType = _normalizeEntityType(profile.entityType);
    final normalizedDocumentType = _normalizeDocumentType(
      profile.companyDocumentType,
      fallbackTaxId: profile.companyTaxId,
    );
    final normalizedCompanyTaxId = BrDocumentsValidator.digitsOnly(
      profile.companyTaxId,
    );
    final normalizedBuyerDocument = BrDocumentsValidator.digitsOnly(
      profile.buyerDocument,
    );
    final normalizedCompanyPhone = BrDocumentsValidator.normalizeBrazilPhone(
      profile.companyPhone,
    );
    final normalizedBuyerPhone = BrDocumentsValidator.normalizeBrazilPhone(
      profile.buyerPhone,
    );

    _assertStrongIdentity(
      companyDocumentType: normalizedDocumentType,
      companyTaxId: normalizedCompanyTaxId,
      buyerDocument: normalizedBuyerDocument,
      companyPhone: normalizedCompanyPhone,
      buyerPhone: normalizedBuyerPhone,
    );

    final payload = UserProfile(
      id: user.uid,
      email: user.email ?? profile.email.trim(),
      role: normalizedRole,
      companyName: profile.companyName.trim(),
      companyLegalName: profile.companyLegalName.trim(),
      companyTaxId: normalizedCompanyTaxId,
      companyPhone: normalizedCompanyPhone,
      companyEmail: profile.companyEmail.trim(),
      entityType: normalizedEntityType,
      companyDocumentType: normalizedDocumentType,
      identityVerificationStatus: 'verified',
      registrationStage: 'active',
      buyerName: profile.buyerName.trim(),
      buyerRoleTitle: profile.buyerRoleTitle.trim(),
      buyerDocument: normalizedBuyerDocument,
      buyerPhone: normalizedBuyerPhone,
      profileCompleted: true,
      profileCompletedAt: now,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );

    final map = payload.toMap();
    map['profileCompleted'] = true;
    map['profileCompletedAt'] = Timestamp.fromDate(now);
    map['updatedAt'] = Timestamp.fromDate(now);
    final existingCreatedAtRaw = currentDocData?['createdAt'];
    map['createdAt'] =
        existingCreatedAtRaw ?? map['createdAt'] ?? Timestamp.fromDate(now);
    map['identityVerificationStatus'] = 'verified';
    map['registrationStage'] = 'active';

    _log(
      '[saveCurrentUserProfile.preWrite] doc.exists=${currentDoc.exists} existingKeys=${(currentDocData?.keys.toList() ?? const [])}',
    );

    _log(
      '[saveCurrentUserProfile] uid=${user.uid} email=${user.email ?? ''} profileCompleted=${map['profileCompleted']} role=$normalizedRole',
    );

    try {
      // Replace document to sanitize legacy keys not allowed by Firestore rules.
      await userRef.set(map);
    } on FirebaseException catch (error) {
      _log(
        '[saveCurrentUserProfile.writeError] code=${error.code} message=${error.message}',
      );
      if (error.code == 'permission-denied') {
        throw Exception(
          'O Firestore recusou salvar o cadastro. Publique as regras mais recentes (firestore.rules) e tente novamente.',
        );
      }
      rethrow;
    }

    DocumentSnapshot<Map<String, dynamic>> verifiedDoc;
    try {
      verifiedDoc = await userRef.get(const GetOptions(source: Source.server));
    } on FirebaseException catch (error) {
      _log(
        '[saveCurrentUserProfile.verifyError] code=${error.code} message=${error.message}',
      );
      throw Exception(
        'Cadastro salvo, mas sem confirmacao no servidor. Verifique conexao/regras e tente novamente.',
      );
    }

    final verifiedData = verifiedDoc.data();
    final profileCompleted = verifiedData?['profileCompleted'] == true;
    _log(
      '[saveCurrentUserProfile.verify] uid=${user.uid} email=${user.email ?? ''} doc.exists=${verifiedDoc.exists} profileCompleted=$profileCompleted role=${(verifiedData?['role'] ?? '').toString()}',
    );

    if (!verifiedDoc.exists || !profileCompleted) {
      throw Exception(
        'Cadastro salvo localmente, mas nao confirmado no Firestore (profileCompleted!=true).',
      );
    }
  }

  Future<void> sendProfileCompletedEmail(String userEmail) async {
    final email = userEmail.trim();
    if (email.isEmpty) {
      return;
    }

    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendProfileCompletedEmail')
          .call({'email': email});
      _log('[sendProfileCompletedEmail] status=called');
    } catch (error) {
      _log('[sendProfileCompletedEmail] status=skipped error=$error');
    }
  }

  Future<UserProfile?> getCurrentUserProfile({bool forceServer = false}) async {
    final user = auth.currentUser;
    if (user == null) {
      return null;
    }

    DocumentSnapshot<Map<String, dynamic>> doc;
    if (forceServer) {
      try {
        doc = await firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));
      } catch (_) {
        doc = await firestore.collection('users').doc(user.uid).get();
      }
    } else {
      doc = await firestore.collection('users').doc(user.uid).get();
    }

    if (!doc.exists) {
      return null;
    }

    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> currentUserProfileStream() {
    final user = auth.currentUser;
    if (user == null) {
      _log(
        '[currentUserProfileStream] uid=null doc.exists=false profileCompleted=null role=null',
      );
      return Stream.value(null);
    }

    return firestore
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .asyncMap((doc) async {
          final data = doc.data();
          final localProfileCompleted = data?['profileCompleted'] == true;
          final role = _normalizeRole((data?['role'] ?? '').toString());
          final fromCache = doc.metadata.isFromCache;
          final hasPendingWrites = doc.metadata.hasPendingWrites;

          _log(
            '[currentUserProfileStream] uid=${user.uid} email=${user.email ?? ''} doc.exists=${doc.exists} localProfileCompleted=$localProfileCompleted role=$role fromCache=$fromCache hasPendingWrites=$hasPendingWrites',
          );

          if (!doc.exists) {
            return null;
          }

          if (localProfileCompleted) {
            return UserProfile.fromFirestore(doc);
          }

          // Protege contra regressao de cache local (false) quando o servidor
          // ja confirma profileCompleted=true.
          try {
            final serverDoc = await doc.reference.get(
              const GetOptions(source: Source.server),
            );
            final serverData = serverDoc.data();
            final serverProfileCompleted =
                serverData?['profileCompleted'] == true;

            _log(
              '[currentUserProfileStream.serverCheck] uid=${user.uid} email=${user.email ?? ''} doc.exists=${serverDoc.exists} serverProfileCompleted=$serverProfileCompleted role=${_normalizeRole((serverData?['role'] ?? '').toString())}',
            );

            if (serverDoc.exists && serverProfileCompleted) {
              return UserProfile.fromFirestore(serverDoc);
            }
          } catch (error) {
            _log('[currentUserProfileStream.serverCheck] error=$error');
          }

          return UserProfile.fromFirestore(doc);
        });
  }

  Future<String?> getCurrentUserRole() async {
    final profile = await getCurrentUserProfile();
    return profile?.role;
  }

  Stream<String?> currentUserRoleStream() {
    return currentUserProfileStream().map((profile) => profile?.role);
  }

  Future<String> getCurrentUserCompanyName() async {
    final profile = await getCurrentUserProfile();
    return profile?.companyName ?? '';
  }

  Future<void> updateCompanyProfile({
    required String companyName,
    required String companyLegalName,
    required String companyPhone,
    required String companyEmail,
    required String buyerName,
    required String buyerRoleTitle,
    required String buyerDocument,
    required String buyerPhone,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final current = await getCurrentUserProfile(forceServer: true);
    if (current == null) {
      throw Exception('Perfil nao encontrado para atualizar.');
    }

    final normalizedCompanyPhone = BrDocumentsValidator.normalizeBrazilPhone(
      companyPhone,
    );
    final normalizedBuyerPhone = BrDocumentsValidator.normalizeBrazilPhone(
      buyerPhone,
    );
    final normalizedBuyerDocument = BrDocumentsValidator.digitsOnly(
      buyerDocument,
    );

    _assertStrongIdentity(
      companyDocumentType: current.companyDocumentType,
      companyTaxId: current.companyTaxId,
      buyerDocument: normalizedBuyerDocument,
      companyPhone: normalizedCompanyPhone,
      buyerPhone: normalizedBuyerPhone,
    );

    final now = Timestamp.now();
    await firestore.collection('users').doc(user.uid).set({
      'companyName': companyName.trim(),
      'companyLegalName': companyLegalName.trim(),
      'companyPhone': normalizedCompanyPhone,
      'companyEmail': companyEmail.trim(),
      'buyerName': buyerName.trim(),
      'buyerRoleTitle': buyerRoleTitle.trim(),
      'buyerDocument': normalizedBuyerDocument,
      'buyerPhone': normalizedBuyerPhone,
      'updatedAt': now,
      'profileCompleted': current.profileCompleted,
      'profileCompletedAt': current.profileCompletedAt == null
          ? null
          : Timestamp.fromDate(current.profileCompletedAt!),
    }, SetOptions(merge: true));

    _log(
      '[updateCompanyProfile] profileCompleted=${current.profileCompleted} role=${current.role}',
    );
  }

  String _normalizeRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'fornecedor' || normalized == 'supplier') {
      return 'supplier';
    }
    if (normalized == 'comprador' || normalized == 'buyer') {
      return 'buyer';
    }
    return 'buyer';
  }

  String _normalizeEntityType(String? entityType) {
    final normalized = (entityType ?? '').trim().toLowerCase();
    if (normalized == 'individual' || normalized == 'pf') {
      return 'individual';
    }
    return 'legal';
  }

  String _normalizeDocumentType(String? type, {required String fallbackTaxId}) {
    final normalized = (type ?? '').trim().toLowerCase();
    if (normalized == 'cpf' || normalized == 'cnpj') {
      return normalized;
    }

    final digits = BrDocumentsValidator.digitsOnly(fallbackTaxId);
    return digits.length == 11 ? 'cpf' : 'cnpj';
  }

  void _assertStrongIdentity({
    required String companyDocumentType,
    required String companyTaxId,
    required String buyerDocument,
    required String companyPhone,
    required String buyerPhone,
  }) {
    if (companyDocumentType == 'cnpj') {
      if (!BrDocumentsValidator.isValidCnpj(companyTaxId)) {
        throw Exception('CNPJ invalido. Revise o documento da empresa.');
      }
    } else {
      if (!BrDocumentsValidator.isValidCpf(companyTaxId)) {
        throw Exception(
          'CPF invalido para cadastro sem CNPJ. Revise o documento.',
        );
      }
    }

    if (!BrDocumentsValidator.isValidCpf(buyerDocument)) {
      throw Exception('CPF do responsavel invalido.');
    }

    if (!BrDocumentsValidator.isValidBrazilWhatsApp(companyPhone)) {
      throw Exception('WhatsApp da empresa invalido.');
    }

    if (!BrDocumentsValidator.isValidBrazilWhatsApp(buyerPhone)) {
      throw Exception('WhatsApp do responsavel invalido.');
    }
  }
}
