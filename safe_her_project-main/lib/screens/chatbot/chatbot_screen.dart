import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../nearby_help/nearby_help_screen.dart';

class _Message {
  const _Message(this.text, this.fromUser);
  final String text;
  final bool fromUser;
}

/// A fully rule-based (keyword-matching) safety assistant — no LLM/API
/// needed, so it's free to run and works completely offline.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [
    const _Message(
      "Hi, I'm your SafeHer Assistant. Ask me about emergency steps, first aid, or nearby help.",
      false,
    ),
  ];

  static const _suggestions = [
    'I feel unsafe, what do I do?',
    'First aid for a cut',
    'Nearby police station',
    'Emergency helpline numbers',
  ];

  static final _knowledgeBase = <List<String>, String>{
    [
      'unsafe',
      'scared',
      'followed',
      'danger',
    ]: "Stay calm. Move to a well-lit, crowded area immediately. Tap the SOS button on Home to alert your trusted contacts with your live location, or call 100 for Police.",
    [
      'first aid',
      'cut',
      'bleeding',
      'wound',
    ]: 'For a cut: wash your hands, apply firm pressure with a clean cloth for a few minutes, then clean the wound and cover with a bandage. Seek medical help if bleeding does not stop.',
    [
      'police',
      'station',
      'cop',
    ]: 'You can find nearby police stations with distance and one-tap calling on the Nearby Help screen. Want me to open it?',
    [
      'helpline',
      'number',
      'emergency contact',
      'call',
    ]: 'Key helplines: Police 100 · Women\'s Helpline 1091 · Ambulance 108 · Fire 101. You can also find these under Contacts.',
    [
      'fake call',
    ]: 'Open Fake Call from Home, pick a caller name and delay, then tap Start Fake Call to simulate an incoming call.',
    [
      'location',
      'share',
      'track',
    ]: 'Tap "Share Your Location" on Home or go to the Tracking tab to share your live location with your trusted contacts.',
    [
      'hospital',
    ]: 'Nearby Help lists hospitals near you with distance, call, and directions — want me to open it?',
    ['thank', 'thanks']: "You're welcome. Stay safe!",
  };

  String _reply(String input) {
    final lower = input.toLowerCase();
    for (final entry in _knowledgeBase.entries) {
      if (entry.key.any(lower.contains)) return entry.value;
    }
    return "I'm not fully sure about that yet, but in any emergency: tap SOS on Home, or call Police at 100. You can also check Nearby Help or Contacts.";
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Message(text.trim(), true));
      _messages.add(_Message(_reply(text), false));
    });
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    if (text.toLowerCase().contains('police') ||
        text.toLowerCase().contains('hospital')) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NearbyHelpScreen()));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.chevron_left_rounded, size: 26),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Safety Assistant',
                    style: AppTextStyles.calloutBold.copyWith(
                      fontSize: 20,
                      height: 33 / 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(19, 16, 19, 16),
                itemCount: _messages.length,
                itemBuilder: (context, i) => _Bubble(message: _messages[i]),
              ),
            ),
            if (_messages.length == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 0, 19, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _suggestions)
                      ActionChip(
                        label: Text(s, style: AppTextStyles.b4),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.neutral300),
                        onPressed: () => _send(s),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 0, 19, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      hint: 'Ask something...',
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _send(_controller.text),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.primary : AppColors.fieldFill,
          border: fromUser ? null : Border.all(color: AppColors.neutral300),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(fromUser ? 14 : 2),
            bottomRight: Radius.circular(fromUser ? 2 : 14),
          ),
        ),
        child: Text(
          message.text,
          style: AppTextStyles.b3.copyWith(
            color: fromUser ? Colors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}
