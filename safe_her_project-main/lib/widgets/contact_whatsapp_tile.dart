import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

/// A single trusted-contact row with a one-tap WhatsApp button — used by
/// any share surface that just needs "pick a contact, open WhatsApp with
/// them pre-filled" (Live Tracking's share sheet, the homepage share
/// sheet, SOS). Shows an "Opened" state once tapped; WhatsApp itself
/// still requires the user to hit Send, so this is not a delivery receipt.
class ContactWhatsAppTile extends StatefulWidget {
  const ContactWhatsAppTile({
    super.key,
    required this.contact,
    required this.message,
  });

  final Contact contact;
  final String message;

  @override
  State<ContactWhatsAppTile> createState() => _ContactWhatsAppTileState();
}

class _ContactWhatsAppTileState extends State<ContactWhatsAppTile> {
  bool _opened = false;

  Future<void> _open() async {
    final ok = await ShareService.openWhatsApp(
      widget.contact.phone,
      widget.message,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _opened = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open WhatsApp")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contact.name, style: AppTextStyles.semibold16),
                Text(widget.contact.phone, style: AppTextStyles.b5),
              ],
            ),
          ),
          if (_opened)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Opened',
                  style: AppTextStyles.b5.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            )
          else
            IconButton(
              onPressed: _open,
              icon: const Icon(Icons.chat_bubble_rounded),
              color: const Color(0xFF25D366),
              tooltip: 'Send via WhatsApp',
            ),
        ],
      ),
    );
  }
}
