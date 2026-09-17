import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../services/admin_data_service.dart';
import '../theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _query = '';
  final _dateFormat = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: AdminDataService.streamUsers(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load users: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final q = _query.trim().toLowerCase();
        final users = snap.data!.where((u) {
          if (q.isEmpty) return true;
          return u.email.toLowerCase().contains(q) || u.fullName.toLowerCase().contains(q) || u.uid.toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark)),
              const SizedBox(height: 4),
              Text('${snap.data!.length} registered accounts.', style: const TextStyle(color: AppColors.neutral900)),
              const SizedBox(height: 18),
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded, size: 18), hintText: 'Search name, email, uid...'),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: users.isEmpty
                    ? const Center(child: Text('No matching users.', style: TextStyle(color: AppColors.neutral400)))
                    : Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral200)),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.surface),
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Blood group')),
                              DataColumn(label: Text('Profile complete')),
                              DataColumn(label: Text('Joined')),
                              DataColumn(label: Text('UID')),
                            ],
                            rows: [
                              for (final u in users)
                                DataRow(cells: [
                                  DataCell(Text(u.fullName.isEmpty ? '—' : u.fullName)),
                                  DataCell(Text(u.email.isEmpty ? '—' : u.email)),
                                  DataCell(Text(u.bloodGroup ?? '—')),
                                  DataCell(Icon(
                                    u.profileComplete ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                    size: 16,
                                    color: u.profileComplete ? AppColors.success : AppColors.neutral400,
                                  )),
                                  DataCell(Text(u.createdAt == null ? '—' : _dateFormat.format(u.createdAt!))),
                                  DataCell(Text(u.uid, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                ]),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
