import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/dashboard_shell.dart';
import 'screens/login_screen.dart';
import 'services/admin_auth_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SafeHerAdminApp());
}

class SafeHerAdminApp extends StatelessWidget {
  const SafeHerAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHer Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Gates the whole app on (1) being signed in and (2) being a verified
/// admin — re-checked on every auth-state change (not just at sign-in
/// time), so a persisted browser session on reload is re-validated too.
/// The dashboard's actual data queries are still independently protected
/// by firestore.rules regardless of what this widget decides.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AdminAuthService.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final user = authSnap.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<bool>(
          future: AdminAuthService.isCurrentUserAdmin(),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }
            if (adminSnap.data != true) {
              return _NotAnAdminScaffold(email: user.email ?? user.uid);
            }
            return const DashboardShell();
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
  }
}

class _NotAnAdminScaffold extends StatelessWidget {
  const _NotAnAdminScaffold({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 40, color: AppColors.danger),
              const SizedBox(height: 14),
              Text(
                '$email is signed in but is not listed as a SafeHer admin.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.dark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ask an existing admin to add your user ID to the Firestore "admins" collection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.neutral400, fontSize: 12),
              ),
              const SizedBox(height: 18),
              OutlinedButton(onPressed: () => AdminAuthService.signOut(), child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
