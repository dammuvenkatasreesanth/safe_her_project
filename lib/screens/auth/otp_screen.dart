import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.verificationId, required this.phoneNumber});

  final String verificationId;
  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;
  final _nodes = List.generate(_codeLength, (_) => FocusNode());
  final _controllers = List.generate(_codeLength, (_) => TextEditingController());
  late String _verificationId = widget.verificationId;
  Timer? _timer;
  int _secondsLeft = 30;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft != 0) return;
    _startTimer();
    await AuthService.sendOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (id) {
        if (mounted) setState(() => _verificationId = id);
      },
      onAutoVerified: (credential) => _handleSuccess(credential.user!.uid),
      onError: (message) {
        if (mounted) setState(() => _error = message);
      },
    );
  }

  Future<void> _verify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < _codeLength) {
      setState(() => _error = 'Enter the full $_codeLength-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final credential = await AuthService.verifyOtp(verificationId: _verificationId, smsCode: code);
      await _handleSuccess(credential.user!.uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Verification failed. Try again.';
      });
    }
  }

  Future<void> _handleSuccess(String uid) async {
    await UserRepository.createIfMissing(uid: uid, phone: widget.phoneNumber);
    final profile = await UserRepository.getProfile(uid);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => profile?.profileComplete == true ? const HomeScreen() : const ProfileSetupScreen(),
      ),
      (route) => false,
    );
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
              Text('Sent by SMS to ${widget.phoneNumber}', style: AppTextStyles.b3),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _codeLength; i++) ...[
                            if (i != 0) const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: TextField(
                                  controller: _controllers[i],
                                  focusNode: _nodes[i],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: AppTextStyles.h5.copyWith(fontSize: 20),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(5),
                                      borderSide: const BorderSide(color: AppColors.neutral300),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v.isNotEmpty && i < _codeLength - 1) {
                                      _nodes[i + 1].requestFocus();
                                    } else if (v.isEmpty && i > 0) {
                                      _nodes[i - 1].requestFocus();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: AppTextStyles.b4.copyWith(color: const Color(0xFFE0334D)), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        "Haven't received the code",
                        style: AppTextStyles.b3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 7),
                      GestureDetector(
                        onTap: _secondsLeft == 0 ? _resend : null,
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
                label: _verifying ? 'Verifying...' : 'Verify & Continue',
                onPressed: _verifying ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
