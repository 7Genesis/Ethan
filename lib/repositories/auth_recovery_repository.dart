import 'package:cloud_functions/cloud_functions.dart';
import 'package:cotahub/core/validators/br_documents.dart';

class AuthRecoveryRepository {
  final FirebaseFunctions functions = FirebaseFunctions.instance;

  Future<WhatsAppRecoveryChallenge> sendPasswordResetOtpViaWhatsApp({
    required String email,
    required String whatsapp,
  }) async {
    final callable = functions.httpsCallable('sendPasswordResetWhatsAppOtp');
    final normalizedPhone = BrDocumentsValidator.normalizeBrazilPhone(whatsapp);
    final response = await callable.call({
      'email': email.trim(),
      'whatsapp': normalizedPhone,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    return WhatsAppRecoveryChallenge(
      requestId: (data['requestId'] ?? '').toString(),
      expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 600,
      destinationMask: (data['destinationMask'] ?? '').toString(),
      devOtpCode: (data['devOtpCode'] ?? '').toString(),
    );
  }

  Future<void> confirmPasswordResetViaWhatsApp({
    required String email,
    required String whatsapp,
    required String requestId,
    required String otpCode,
    required String newPassword,
  }) async {
    final callable = functions.httpsCallable('confirmPasswordResetWhatsAppOtp');
    final normalizedPhone = BrDocumentsValidator.normalizeBrazilPhone(whatsapp);
    await callable.call({
      'email': email.trim(),
      'whatsapp': normalizedPhone,
      'requestId': requestId.trim(),
      'otpCode': otpCode.trim(),
      'newPassword': newPassword,
    });
  }
}

class WhatsAppRecoveryChallenge {
  final String requestId;
  final int expiresInSeconds;
  final String destinationMask;
  final String devOtpCode;

  const WhatsAppRecoveryChallenge({
    required this.requestId,
    required this.expiresInSeconds,
    required this.destinationMask,
    required this.devOtpCode,
  });
}
