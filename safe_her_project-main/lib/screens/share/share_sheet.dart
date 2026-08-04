import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/contacts_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/contact_whatsapp_tile.dart';
import '../../widgets/primary_button.dart';

Future<void> showShareSheet(BuildContext context, {LatLng? location}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
    ),
    builder: (context) => _ShareSheetContent(location: location),
  );
}

class _ShareSheetContent extends StatefulWidget {
  const _ShareSheetContent({required this.location});

  final LatLng? location;

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<_ShareSheetContent> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _message => ShareService.buildLocationMessage(
    widget.location ?? const LatLng(0, 0),
    note: _noteController.text,
  );

  @override
  Widget build(BuildContext context) {
    final contacts = ContactsService.contacts;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        15,
        26,
        MediaQuery.of(context).viewInsets.bottom + 23,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 57,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.dot,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Write Message (Optional)',
              hintStyle: AppTextStyles.b3.copyWith(color: AppColors.neutral300),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.r4),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Share Now',
            onPressed: widget.location == null
                ? null
                : () {
                    ShareService.shareViaOtherApps(_message);
                    Navigator.pop(context);
                  },
          ),
          const SizedBox(height: 18),
          Text(
            'Send via WhatsApp',
            style: AppTextStyles.semibold16.copyWith(
              fontSize: 18,
              height: 33 / 18,
            ),
          ),
          const SizedBox(height: 7),
          if (widget.location == null)
            Text('Locating...', style: AppTextStyles.b4)
          else if (contacts.isEmpty)
            Text(
              'No trusted contacts yet. Add them in the Contacts tab.',
              style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
            )
          else
            for (final contact in contacts)
              ContactWhatsAppTile(contact: contact, message: _message),
        ],
      ),
    );
  }
}
