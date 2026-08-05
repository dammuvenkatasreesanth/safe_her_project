import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import 'auth/profile_setup_screen.dart';
import 'home/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final _scale = Tween(
    begin: 0.92,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2000), _routeNext);
  }

  Future<void> _routeNext() async {
    if (!mounted) return;

    final user = AuthService.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacement(slideRoute(const OnboardingScreen()));
      return;
    }

    // Already signed in from a previous session — skip onboarding/auth entirely.
    final profile = await UserRepository.getProfile(user.uid);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      slideRoute(profile?.profileComplete == true ? const HomeScreen() : const ProfileSetupScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 175,
                  height: 84,
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.b3.copyWith(
                      color: const Color(0xFF1D1D1D),
                    ),
                    children: const [
                      TextSpan(text: 'Your '),
                      TextSpan(
                        text: 'shield',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      TextSpan(text: ', '),
                      TextSpan(
                        text: 'one tap',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      TextSpan(text: ' away'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
