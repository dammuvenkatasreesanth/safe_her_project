import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/figma_illustration.dart';
import '../../widgets/onboarding_dots.dart';
import '../../widgets/primary_button.dart';
import '../auth/signup_screen.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  final Widget illustration;
  final String title;
  final String subtitle;
  final String buttonLabel;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardingPageData(
      illustration: onboarding1Illustration,
      title: 'Help, one tap away',
      subtitle: 'Press SOS or shake twice. We alert your contacts instantly.',
      buttonLabel: 'Next',
    ),
    _OnboardingPageData(
      illustration: onboarding2Illustration,
      title: 'Your people, always in the loop',
      subtitle: 'Add contacts once. Share your live location with one tap.',
      buttonLabel: 'Next',
    ),
    _OnboardingPageData(
      illustration: onboarding3Illustration,
      title: 'Smart safety,\n always on',
      subtitle:
          'We sense trouble, suggest safer routes, and save evidence — automatically.',
      buttonLabel: 'Get Started',
    ),
  ];

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(slideRoute(const SignupScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    child: Center(child: page.illustration),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 0, 19, 24),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(_index),
                      children: [
                        Text(
                          _pages[_index].title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h5,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _pages[_index].subtitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.b3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  OnboardingDots(count: _pages.length, index: _index),
                  const SizedBox(height: 35),
                  PrimaryButton(
                    label: _pages[_index].buttonLabel,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
