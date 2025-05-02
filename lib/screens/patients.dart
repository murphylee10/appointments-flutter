import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper().getPatients();
    setState(() {
      _all = list;
      _filter();
    });
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered = _all.where((p) {
          return p.firstName.toLowerCase().contains(q) ||
                 p.lastName.toLowerCase().contains(q)  ||
                 p.email.toLowerCase().contains(q)     ||
                 p.phone.toLowerCase().contains(q);
        }).toList();
      }
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

    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');

    if (rows.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV contains no rows.')),
      );
      return;
    }

    // Skip header row; expect 7 columns per row
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 7) continue;
      final p = Patient(
        firstName: row[0]?.toString() ?? '',
        middleName: row[1]?.toString().isEmpty == true ? null : row[1]?.toString(),
        lastName: row[2]?.toString() ?? '',
        gender: row[3]?.toString() ?? '',
        dob: row[4]?.toString() ?? '',
        email: row[5]?.toString() ?? '',
        phone: row[6]?.toString() ?? '',
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
      text: patient != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(patient.dob))
          : '',
    );
    final email = TextEditingController(text: patient?.email);
    final phone = TextEditingController(text: patient?.phone);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(isNew ? 'Add Patient' : 'Edit Patient'),
          content: Form(
            key: fk,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: fn,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: mn,
                  decoration: const InputDecoration(labelText: 'Middle Name'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ln,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['M', 'F', 'O']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => gender = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: dob,
                  decoration:
                      const InputDecoration(labelText: 'Date of Birth'),
                  readOnly: true,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: patient != null
                          ? DateTime.parse(patient.dob)
                          : DateTime(2000, 1, 1),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      dob.text = DateFormat('yyyy-MM-dd').format(d);
                      setState(() {});
                    }
                  },
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!fk.currentState!.validate()) return;
                final p = Patient(
                  id: patient?.id,
                  firstName: fn.text,
                  middleName: mn.text.isEmpty ? null : mn.text,
                  lastName: ln.text,
                  gender: gender!,
                  dob: dob.text,
                  email: email.text,
                  phone: phone.text,
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
    // no manual dispose here
  }

  Future<void> _confirmDelete(Patient p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text('Delete ${p.firstName} ${p.lastName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search + Add + Import
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name/email/phone…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Two-direction scroll with attached controllers
            Expanded(
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
                        constraints: const BoxConstraints(minWidth: 900),
                        child: DataTable(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          headingRowColor:
                              MaterialStateProperty.all(Colors.grey[200]),
                          columns: const [
                            DataColumn(label: Text('First')),
                            DataColumn(label: Text('Middle')),
                            DataColumn(label: Text('Last')),
                            DataColumn(label: Text('Gender')),
                            DataColumn(label: Text('DOB')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Phone')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _filtered.map((p) {
                            return DataRow(cells: [
                              DataCell(Text(p.firstName)),
                              DataCell(Text(p.middleName ?? '')),
                              DataCell(Text(p.lastName)),
                              DataCell(Text(p.gender)),
                              DataCell(Text(p.dob)),
                              DataCell(Text(p.email)),
                              DataCell(Text(p.phone)),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon:
                                        const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showForm(patient: p),
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.delete, size: 20),
                                    onPressed: () => _confirmDelete(p),
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
          ],
        ),
      ),
    );
  }
}
