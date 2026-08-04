import 'package:flutter/material.dart';
import '../../models/contact.dart';
import '../../services/contacts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const _helplines = [
    (label: 'Police', number: '100'),
    (label: "Women's Helpline", number: '1091'),
    (label: 'Ambulance', number: '108'),
    (label: 'Fire', number: '101'),
  ];

  Future<void> _addContact() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Trusted Contact',
              style: AppTextStyles.h5.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 20),
            _LabeledField(
              label: 'Name',
              controller: nameController,
              hint: 'Contact name',
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Phone Number',
              controller: phoneController,
              hint: '+91 00000 00000',
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Contact',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (result == true && nameController.text.trim().isNotEmpty) {
      setState(() {
        ContactsService.addContact(
          nameController.text.trim(),
          phoneController.text.trim(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ContactsService.contacts;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Emergency Contacts'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trusted Contacts',
                        style: AppTextStyles.semibold16.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'First contact is alerted first when SOS is triggered.',
                        style: AppTextStyles.b4.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < contacts.length; i++)
                        _ContactTile(index: i, contact: contacts[i]),
                      const SizedBox(height: 6),
                      PrimaryButton(
                        label: '+  Add Contact',
                        radius: AppRadius.r5,
                        height: 47,
                        outlined: true,
                        onPressed: _addContact,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Emergency Helplines',
                        style: AppTextStyles.semibold16.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (var i = 0; i < _helplines.length; i++) ...[
                            if (i != 0) const SizedBox(width: 11),
                            Expanded(
                              child: _HelplineCard(
                                label: _helplines[i].label,
                                number: _helplines[i].number,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.index, required this.contact});

  final int index;
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: AppTextStyles.b3.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: AppTextStyles.semibold16),
                const SizedBox(height: 3),
                Text(contact.phone, style: AppTextStyles.b5),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelplineCard extends StatelessWidget {
  const _HelplineCard({required this.label, required this.number});

  final String label;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_phone_rounded, size: 18),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.b4, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(number, style: AppTextStyles.semibold16),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.b2),
        const SizedBox(height: 8),
        AppTextField(controller: controller, hint: hint),
      ],
    );
  }
}
