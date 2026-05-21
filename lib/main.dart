import 'package:cotahub/features/auth/pages/complete_profile_page.dart';
import 'package:cotahub/features/auth/pages/email_verification_page.dart';
import 'package:cotahub/features/auth/pages/login_page.dart';
import 'package:cotahub/features/home/pages/home_page.dart';
import 'package:cotahub/features/supplier/pages/supplier_home_page.dart';
import 'package:cotahub/firebase_options.dart';
import 'package:cotahub/models/user_profile.dart';
import 'package:cotahub/repositories/user_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CotahubApp());
}

class CotahubApp extends StatelessWidget {
  const CotahubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userRepository = UserRepository();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cotahub',
      theme: CotahubTheme.buildTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          final authUser = authSnapshot.data;
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
