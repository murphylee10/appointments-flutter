import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  _PatientsScreenState createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late Future<List<Patient>> _patients;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _loadPatients() {
    setState(() {
      _patients = DatabaseHelper().getPatients();
    });
  }

  Future<void> _showAddPatientDialog() async {
    final firstNameController = TextEditingController();
    final middleNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final genderController = TextEditingController();
    final dobController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Patient'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: firstNameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                TextField(
                  controller: middleNameController,
                  decoration: const InputDecoration(labelText: 'Middle Name'),
                ),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
                TextField(
                  controller: genderController,
                  decoration: const InputDecoration(labelText: 'Gender'),
                ),
                TextField(
                  controller: dobController,
                  decoration: const InputDecoration(labelText: 'Date of Birth'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final newPatient = Patient(
                  firstName: firstNameController.text,
                  middleName: middleNameController.text.isEmpty
                      ? null
                      : middleNameController.text,
                  lastName: lastNameController.text,
                  gender: genderController.text,
                  dob: dobController.text,
                  email: emailController.text,
                  phone: phoneController.text,
                );
                await DatabaseHelper().insertPatient(newPatient);
                _loadPatients();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
      ),
      body: FutureBuilder<List<Patient>>(
        future: _patients,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Error loading patients: ${snapshot.error}');
            // print('Stack trace: ${snapshot.stackTrace}');
            return const Center(child: Text('Error loading patients'));
          } else if (snapshot.hasData) {
            final patients = snapshot.data!;
            return DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('First Name')),
                DataColumn(label: Text('Middle Name')),
                DataColumn(label: Text('Last Name')),
                DataColumn(label: Text('Gender')),
                DataColumn(label: Text('DOB')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Phone')),
              ],
              rows: patients.map((patient) {
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(patient.firstName)),
                    DataCell(Text(patient.middleName ?? '')),
                    DataCell(Text(patient.lastName)),
                    DataCell(Text(patient.gender)),
                    DataCell(Text(patient.dob)),
                    DataCell(Text(patient.email)),
                    DataCell(Text(patient.phone)),
                  ],
                );
              }).toList(),
            );
          } else {
            return const Center(child: Text('No patients found'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPatientDialog,
        tooltip: 'Add New Patient',
        child: const Icon(Icons.add),
      ),
    );
  }
}
