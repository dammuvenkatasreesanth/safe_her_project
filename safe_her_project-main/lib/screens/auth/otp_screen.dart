import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _nodes = List.generate(4, (_) => FocusNode());
  final _controllers = List.generate(4, (_) => TextEditingController());
  Timer? _timer;
  int _secondsLeft = 24;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 24;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final n in _nodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 44),
              Text('Enter the code', style: AppTextStyles.h5),
              const SizedBox(height: 11),
              Text('Sent by SMS to +917901289093', style: AppTextStyles.b3),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 245,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i != 0) const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 55,
                                child: TextField(
                                  controller: _controllers[i],
                                  focusNode: _nodes[i],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: AppTextStyles.h5.copyWith(
                                    fontSize: 22,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(
                                        color: AppColors.neutral300,
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v.isNotEmpty && i < 3) {
                                      _nodes[i + 1].requestFocus();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Haven't received the code",
                        style: AppTextStyles.b3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 7),
                      GestureDetector(
                        onTap: _secondsLeft == 0 ? _startTimer : null,
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.b3,
                            children: [
                              const TextSpan(text: 'Resend code in '),
                              TextSpan(
                                text: _secondsLeft == 0
                                    ? 'now'
                                    : '(0:${_secondsLeft.toString().padLeft(2, '0')})',
                                style: AppTextStyles.b3.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Verify & Continue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfileSetupScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
