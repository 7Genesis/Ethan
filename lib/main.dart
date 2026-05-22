import 'package:ethan/features/auth/pages/complete_profile_page.dart';
import 'package:ethan/features/auth/pages/email_verification_page.dart';
import 'package:ethan/features/auth/pages/login_page.dart';
import 'package:ethan/features/home/pages/home_page.dart';
import 'package:ethan/features/supplier/pages/supplier_home_page.dart';
import 'package:ethan/firebase_options.dart';
import 'package:ethan/models/user_profile.dart';
import 'package:ethan/repositories/user_repository.dart';
import 'package:ethan/theme/ethan_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void _debugMainLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateFirebaseAppCheck();
  runApp(const ProjetoEthanApp());
}

Future<void> _activateFirebaseAppCheck() async {
  final AndroidAppCheckProvider androidProvider = kDebugMode
      ? const AndroidDebugProvider()
      : const AndroidPlayIntegrityProvider();
  final AppleAppCheckProvider appleProvider = kDebugMode
      ? const AppleDebugProvider()
      : const AppleAppAttestWithDeviceCheckFallbackProvider();

  if (kIsWeb) {
    const recaptchaSiteKey = String.fromEnvironment(
      'FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY',
      defaultValue: '',
    );

    if (recaptchaSiteKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[appCheck] skipped on web: missing FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY',
        );
        return;
      }
      throw StateError(
        'Missing FIREBASE_APPCHECK_RECAPTCHA_SITE_KEY for web App Check.',
      );
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider(recaptchaSiteKey),
      providerAndroid: androidProvider,
      providerApple: appleProvider,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: androidProvider,
    providerApple: appleProvider,
  );
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
}

class ProjetoEthanApp extends StatelessWidget {
  const ProjetoEthanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userRepository = UserRepository();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Projeto Ethan',
      theme: EthanTheme.buildTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          final authUser = authSnapshot.data;
          _debugMainLog('[main.authGate] uid=${authUser?.uid}');
          if (authUser == null) {
            return const LoginPage();
          }

          if (authUser.emailVerified != true) {
            return const EmailVerificationPage();
          }

          return StreamBuilder<UserProfile?>(
            stream: userRepository.currentUserProfileStream(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingView();
              }

              final profile = profileSnapshot.data;
              _debugMainLog(
                '[main.profileGate] uid=${authUser.uid} profileExists=${profile != null} profileCompleted=${profile?.profileCompleted} role=${profile?.role}',
              );

              if (profile == null) {
                return const CompleteProfilePage();
              }

              if (profile.profileCompleted != true) {
                return CompleteProfilePage(profile: profile);
              }

              if (profile.isSupplier) {
                return const SupplierHomePage();
              }

              return const HomePage();
            },
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
