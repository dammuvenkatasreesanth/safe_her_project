import 'dart:async';
import 'package:flutter/material.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerNumber,
  });

  final String callerName;
  final String callerNumber;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _accepted = false;
  bool _muted = false;
  bool _speaker = false;
  int _elapsed = 0;
  Timer? _timer;

  void _accept() {
    setState(() => _accepted = true);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => setState(() => _elapsed++),
    );
  }

  void _end() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _durationLabel {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static const _avatarColor = Color(0xFF0B5C6B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                _accepted ? _durationLabel : 'Incoming call...',
                style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                widget.callerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Phone  ${widget.callerNumber}',
                style: const TextStyle(color: Color(0xFFAEAEB2), fontSize: 16),
              ),
              const SizedBox(height: 40),
              Container(
                width: 170,
                height: 170,
                decoration: ShapeDecoration(
                  color: _avatarColor,
                  shape: const StarBorder(
                    points: 14,
                    innerRadiusRatio: 0.92,
                    pointRounding: 0.5,
                    valleyRounding: 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.callerName.isNotEmpty
                      ? widget.callerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (_accepted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToolButton(
                      icon: Icons.dialpad_rounded,
                      label: 'Keypad',
                      active: false,
                      onTap: () {},
                    ),
                    _ToolButton(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: 'Mute',
                      active: _muted,
                      onTap: () => setState(() => _muted = !_muted),
                    ),
                    _ToolButton(
                      icon: Icons.volume_up_rounded,
                      label: 'Speaker',
                      active: _speaker,
                      onTap: () => setState(() => _speaker = !_speaker),
                    ),
                    _ToolButton(
                      icon: Icons.more_vert_rounded,
                      label: 'More',
                      active: false,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: Material(
                    color: const Color(0xFFFF453A),
                    borderRadius: BorderRadius.circular(32),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: _end,
                      child: const Center(
                        child: Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      icon: Icons.call_end_rounded,
                      color: const Color(0xFFFF453A),
                      label: 'Decline',
                      onTap: _end,
                    ),
                    _CallButton(
                      icon: Icons.call_rounded,
                      color: const Color(0xFF34C759),
                      label: 'Accept',
                      onTap: _accept,
                    ),
                  ],
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF1C1C1E) : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
