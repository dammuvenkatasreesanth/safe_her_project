import 'package:flutter/material.dart';
import '../../services/device_contacts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';

enum _LoadState { loading, permissionDenied, empty, loaded, error }

/// Lets the user multi-select from their device's contacts to add as
/// SafeHer emergency contacts. Pops with the selected [DeviceContact]s (or
/// null if the user backs out) — persistence is the caller's job, since
/// signup and the main Contacts screen save through different paths
/// (ContactsRepository directly vs. ContactProvider).
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key, required this.maxSelectable});

  /// How many more contacts the caller can actually use (e.g. remaining
  /// slots under the 5-contact cap) — caps selection so this screen can't
  /// hand back more than the caller can save.
  final int maxSelectable;

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  _LoadState _state = _LoadState.loading;
  List<DeviceContact> _all = [];
  final _selected = <DeviceContact>{};
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() => _query = _searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final granted = await DeviceContactsService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() => _state = _LoadState.permissionDenied);
        return;
      }
      final contacts = await DeviceContactsService.fetchContacts();
      if (!mounted) return;
      setState(() {
        _all = contacts;
        _state = contacts.isEmpty ? _LoadState.empty : _LoadState.loaded;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  List<DeviceContact> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
  }

  void _toggle(DeviceContact c) {
    setState(() {
      if (_selected.contains(c)) {
        _selected.remove(c);
        return;
      }
      if (_selected.length >= widget.maxSelectable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can add up to ${widget.maxSelectable} more contact${widget.maxSelectable == 1 ? '' : 's'}.',
            ),
          ),
        );
        return;
      }
      _selected.add(c);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Import Contacts'),
              const SizedBox(height: 4),
              Text(
                'Select up to ${widget.maxSelectable} contact${widget.maxSelectable == 1 ? '' : 's'} to add as emergency contacts.',
                style: AppTextStyles.b3,
              ),
              const SizedBox(height: 14),
              if (_state == _LoadState.loaded || _state == _LoadState.empty) ...[
                AppTextField(
                  controller: _searchController,
                  hint: 'Search your contacts',
                  prefix: const Icon(Icons.search_rounded, size: 20, color: AppColors.neutral400),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(child: _body()),
              if (_state == _LoadState.loaded) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _selected.isEmpty
                      ? 'Select contacts to continue'
                      : 'Add ${_selected.length} contact${_selected.length == 1 ? '' : 's'}',
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      case _LoadState.permissionDenied:
        return _Message(
          icon: Icons.contacts_outlined,
          text: "SafeHer needs permission to read your contacts to import them. "
              "You can allow it from your phone's Settings, then try again.",
          actionLabel: 'Try again',
          onAction: _load,
        );
      case _LoadState.error:
        return _Message(
          icon: Icons.error_outline_rounded,
          text: "Couldn't load your contacts. Please try again.",
          actionLabel: 'Retry',
          onAction: _load,
        );
      case _LoadState.empty:
        return const _Message(
          icon: Icons.contacts_outlined,
          text: 'No contacts with phone numbers were found on this device.',
        );
      case _LoadState.loaded:
        final visible = _visible;
        if (visible.isEmpty) {
          return Center(
            child: Text('No contacts match "$_query".', style: AppTextStyles.b3),
          );
        }
        return ListView.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = visible[i];
            final checked = _selected.contains(c);
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.r4),
              onTap: () => _toggle(c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: checked ? AppColors.primary : AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: AppTextStyles.semibold16,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(c.phone, style: AppTextStyles.b5),
                        ],
                      ),
                    ),
                    Icon(
                      checked ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: checked ? AppColors.primary : AppColors.neutral400,
                    ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.neutral400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.b3.copyWith(color: AppColors.neutral400),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
