import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'billing_history.dart';
import 'patient_profile.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  _PatientsScreenState createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  List<Patient> _all = [];
  List<Patient> _filtered = [];

  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 25;

  int get _totalPages => (_filtered.length / _pageSize).ceil();

  List<Patient> get _paginatedPatients {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _all = await DatabaseHelper().getPatients();
    _applyFilter();
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
        ? List.from(_all)
        : _all.where((p) =>
            p.firstName.toLowerCase().contains(q) ||
            p.lastName.toLowerCase().contains(q) ||
            (p.phone?.toLowerCase().contains(q) ?? false)
          ).toList();
      _filtered.sort((a, b) => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()));
      _currentPage = 0; // Reset to first page on filter change
    });
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;

    var content = await File(path).readAsString();
    // Strip BOM if present and normalize line endings
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV contains no data.')),
      );
      return;
    }

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 8) continue;
      final p = Patient(
        firstName: row[0]?.toString() ?? '',
        middleName: row[1]?.toString().isEmpty == true ? null : row[1]?.toString(),
        lastName: row[2]?.toString() ?? '',
        gender: row[3]?.toString().isEmpty == true ? null : row[3]?.toString(),
        dob: row[4]?.toString().isEmpty == true ? null : row[4]?.toString(),
        email: row[5]?.toString().isEmpty == true ? null : row[5]?.toString(),
        phone: row[6]?.toString().isEmpty == true ? null : row[6]?.toString(),
        address: row[7]?.toString().isEmpty == true ? null : row[7]?.toString(),
      );
      await DatabaseHelper().insertPatient(p);
    }

    await _load();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV imported successfully')),
    );
  }

  Future<void> _showForm({Patient? patient}) async {
    final isNew = patient == null;
    final fk = GlobalKey<FormState>();
    final fn = TextEditingController(text: patient?.firstName);
    final mn = TextEditingController(text: patient?.middleName);
    final ln = TextEditingController(text: patient?.lastName);
    String? gender = patient?.gender;
    final dob = TextEditingController(
      text: patient?.dob != null && patient!.dob!.isNotEmpty
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(patient.dob!))
          : '',
    );
    final email = TextEditingController(text: patient?.email);
    final phone = TextEditingController(text: patient?.phone);
    final address = TextEditingController(text: patient?.address);

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(isNew ? 'Add Patient' : 'Edit Patient'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: fk,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fn,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: mn,
                    decoration: const InputDecoration(labelText: 'Middle Name'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: ln,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        final key = event.character?.toUpperCase();
                        if (key == 'M') {
                          setState(() => gender = 'M');
                          return KeyEventResult.handled;
                        } else if (key == 'F') {
                          setState(() => gender = 'F');
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['M', 'F']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => gender = v),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: dob,
                    decoration: const InputDecoration(labelText: 'Date of Birth'),
                    readOnly: true,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: patient?.dob != null && patient!.dob!.isNotEmpty
                            ? DateTime.parse(patient.dob!)
                            : DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        dob.text = DateFormat('yyyy-MM-dd').format(d);
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: () async {
                if (!fk.currentState!.validate()) return;
                final p = Patient(
                  id: patient?.id,
                  firstName: fn.text,
                  middleName: mn.text.isEmpty ? null : mn.text,
                  lastName: ln.text,
                  gender: gender,
                  dob: dob.text.isEmpty ? null : dob.text,
                  email: email.text.isEmpty ? null : email.text,
                  phone: phone.text.isEmpty ? null : phone.text,
                  address: address.text.isEmpty ? null : address.text,
                );
                if (isNew) {
                  await DatabaseHelper().insertPatient(p);
                } else {
                  await DatabaseHelper().updatePatient(p);
                }
                Navigator.pop(context);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Patient p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
            const SizedBox(width: AppSpacing.sm),
            const Text('Delete Patient'),
          ],
        ),
        content: Text.rich(
          TextSpan(
            text: 'Are you sure you want to delete ',
            children: [
              TextSpan(
                text: '${p.firstName} ${p.lastName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper().deletePatient(p.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Search + Add + Import
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search by name or phone…',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () => _showForm(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _importCsv,
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Import CSV'),
                    ),
                  ],
                ),
              ),
            ),

            // Patients table
            Expanded(
              child: Card(
                child: Scrollbar(
                  controller: _vController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vController,
                    child: Scrollbar(
                      controller: _hController,
                      thumbVisibility: true,
                      notificationPredicate: (n) => n.depth == 1,
                      child: SingleChildScrollView(
                        controller: _hController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1000),
                          child: DataTable(
                            showCheckboxColumn: false,
                            columns: const [
                              DataColumn(label: Text('Last')),
                              DataColumn(label: Text('First')),
                              DataColumn(label: Text('Gender')),
                              DataColumn(label: Text('DOB')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _paginatedPatients.map((patient) {
                              return DataRow(
                                onSelectChanged: (_) async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PatientProfileScreen(patient: patient),
                                    ),
                                  );
                                  _load(); // Reload list to reflect any changes
                                },
                                cells: [
                                DataCell(Text(patient.lastName)),
                                DataCell(Text(patient.firstName)),
                                DataCell(Text(patient.gender ?? '')),
                                DataCell(Text(patient.dob ?? '')),
                                DataCell(Text(patient.phone ?? '')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.history, size: 20),
                                      tooltip: 'Billing History',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BillingHistoryPage(patient: patient),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      tooltip: 'Edit Patient',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showForm(patient: patient),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      tooltip: 'Delete Patient',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDelete(patient),
                                    ),
                                  ],
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pagination controls
            if (_filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Showing ${_currentPage * _pageSize + 1}–${((_currentPage + 1) * _pageSize).clamp(1, _filtered.length)} of ${_filtered.length}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      tooltip: 'Previous page',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Page ${_currentPage + 1} of ${_totalPages == 0 ? 1 : _totalPages}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < _totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                      tooltip: 'Next page',
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
