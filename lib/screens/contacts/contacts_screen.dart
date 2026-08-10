import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contact.dart';
import '../../providers/contact_provider.dart';
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

  late final ContactProvider _provider;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _provider = ContactProvider()..init();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _openContactSheet({Contact? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final relationController = TextEditingController(
      text: existing?.relation ?? '',
    );
    var makePrimary = existing?.isPrimary ?? false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            setSheetState(() => errorText = null);
            final String? result;
            if (existing == null) {
              result = await _provider.addContact(
                name: nameController.text,
                phone: phoneController.text,
                relation: relationController.text,
                isPrimary: makePrimary,
              );
            } else {
              result = await _provider.updateContact(
                contactId: existing.id,
                name: nameController.text,
                phone: phoneController.text,
                relation: relationController.text,
              );
              if (result == null &&
                  makePrimary &&
                  !existing.isPrimary) {
                await _provider.setPrimary(existing.id);
              }
            }
            if (result != null) {
              setSheetState(() => errorText = result);
              return;
            }
            if (mounted) Navigator.of(sheetContext).pop();
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add Trusted Contact' : 'Edit Contact',
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
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _LabeledField(
                  label: 'Relation (optional)',
                  controller: relationController,
                  hint: 'e.g. Mother, Friend, Neighbour',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: makePrimary,
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setSheetState(() => makePrimary = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Alert this contact first when SOS is triggered',
                        style: AppTextStyles.b4,
                      ),
                    ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: AppTextStyles.b4.copyWith(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _provider,
                  builder: (context, _) => PrimaryButton(
                    label: _provider.isMutating
                        ? 'Saving...'
                        : existing == null
                        ? 'Save Contact'
                        : 'Save Changes',
                    onPressed: _provider.isMutating ? null : submit,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r5),
        ),
        title: const Text('Remove contact?'),
        content: Text(
          'Remove ${contact.name} from your trusted contacts? '
          "They won't be alerted during an SOS anymore.",
          style: AppTextStyles.b3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await _provider.deleteContact(contact.id);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<ContactProvider>(
        builder: (context, provider, _) {
          final contacts = provider.search(_query);
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
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: provider.retry,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 16, bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trusted Contacts',
                                style: AppTextStyles.semibold16.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Primary contact is alerted first when SOS is triggered.',
                                style: AppTextStyles.b4.copyWith(
                                  color: AppColors.neutral400,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (provider.contacts.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: AppTextField(
                                    controller: _searchController,
                                    hint: 'Search contacts',
                                    prefix: const Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                      color: AppColors.neutral400,
                                    ),
                                  ),
                                ),
                              if (provider.isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              else if (provider.error != null &&
                                  provider.contacts.isEmpty)
                                _ErrorState(
                                  message: provider.error!,
                                  onRetry: provider.retry,
                                )
                              else if (contacts.isEmpty && _query.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    'No contacts match "$_query".',
                                    style: AppTextStyles.b4.copyWith(
                                      color: AppColors.neutral400,
                                    ),
                                  ),
                                )
                              else if (contacts.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    'No trusted contacts yet. Add up to '
                                    '5 people to alert during an SOS.',
                                    style: AppTextStyles.b4.copyWith(
                                      color: AppColors.neutral400,
                                    ),
                                  ),
                                )
                              else
                                for (final c in contacts)
                                  _ContactTile(
                                    contact: c,
                                    onTap: () =>
                                        _openContactSheet(existing: c),
                                    onDelete: () => _confirmDelete(c),
                                    onMakePrimary: c.isPrimary
                                        ? null
                                        : () => _provider.setPrimary(c.id),
                                  ),
                              const SizedBox(height: 6),
                              PrimaryButton(
                                label: provider.hasReachedLimit
                                    ? 'Limit of 5 contacts reached'
                                    : '+  Add Contact',
                                radius: AppRadius.r5,
                                height: 47,
                                outlined: true,
                                onPressed: provider.hasReachedLimit
                                    ? null
                                    : () => _openContactSheet(),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Emergency Helplines',
                                style: AppTextStyles.semibold16.copyWith(
                                  fontSize: 18,
                                ),
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
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onDelete,
    required this.onMakePrimary,
  });

  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMakePrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: contact.isPrimary ? AppColors.primary : AppColors.neutral300,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r4),
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
              child: Icon(
                contact.isPrimary ? Icons.star_rounded : Icons.person_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.name,
                          style: AppTextStyles.semibold16,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (contact.isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRIMARY',
                            style: AppTextStyles.b5.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact.relation.isEmpty
                        ? contact.phone
                        : '${contact.phone} · ${contact.relation}',
                    style: AppTextStyles.b5,
                  ),
                ],
              ),
            ),
            if (onMakePrimary != null)
              IconButton(
                tooltip: 'Make primary',
                icon: const Icon(Icons.star_border_rounded, size: 20),
                color: AppColors.neutral400,
                onPressed: onMakePrimary,
              ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.neutral400,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTextStyles.b4.copyWith(color: Colors.red)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Retry'),
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
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.b2),
        const SizedBox(height: 8),
        AppTextField(
          controller: controller,
          hint: hint,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
