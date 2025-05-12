import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

/// A SearchDelegate to find patients by name/email/phone.
class PatientSearchDelegate extends SearchDelegate<Patient?> {
  final List<Patient> patients;
  PatientSearchDelegate(this.patients);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.toLowerCase();
    final matches = patients.where((p) {
      return p.firstName.toLowerCase().contains(q) ||
          p.lastName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          p.phone.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (_, i) {
        final p = matches[i];
        return ListTile(
          title: Text('${p.firstName} ${p.lastName}'),
          subtitle: Text('${p.email} • ${p.phone}'),
          onTap: () => close(context, p),
        );
      },
    );
  }
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointmentsForDate = [];
  List<Patient> _allPatients = [];

  // half-hour slots 09:00–16:30
  static final List<TimeOfDay> _timeSlots = List.generate(
    16,
    (i) => TimeOfDay(hour: 9 + (i ~/ 2), minute: (i % 2) * 30),
  );

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadAppointments();
  }

  Future<void> _loadPatients() async {
    _allPatients = await DatabaseHelper().getPatients();
  }

  Future<void> _loadAppointments() async {
    final all = await DatabaseHelper().getAppointments();
    _appointmentsForDate = all
        .where((a) => _sameDate(a.dateTime, _selectedDate))
        .toList();
    setState(() {});
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Patient? _findPatient(int id) {
    try {
      return _allPatients.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteAppointment(int id) async {
    await DatabaseHelper().deleteAppointment(id);
    _loadAppointments();
  }

  Future<void> _showAddAppointmentDialog(TimeOfDay slot) async {
    final formKey = GlobalKey<FormState>();
    int? selectedPatientId;
    Patient? pickedPatient;
    final patientController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add to ${slot.format(context)}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: patientController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Patient',
                hintText: 'Search patient…',
                suffixIcon: const Icon(Icons.search),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please select a patient' : null,
              onTap: () async {
                final result = await showSearch<Patient?>(
                  context: context,
                  delegate: PatientSearchDelegate(_allPatients),
                );
                if (result != null) {
                  pickedPatient = result;
                  selectedPatientId = result.id!;
                  patientController.text =
                      '${result.firstName} ${result.lastName}';
                  setState(() {});
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final dt = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  slot.hour,
                  slot.minute,
                );
                await DatabaseHelper().insertAppointment(
                  Appointment(
                    patientId: selectedPatientId!,
                    dateTime: dt,
                    notes: '',
                  ),
                );
                Navigator.pop(context);
                _loadAppointments();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    // patientController will be garbage-collected after the dialog closes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar is provided by HomeScreen
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1) Calendar picker
            CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              onDateChanged: (d) {
                _selectedDate = d;
                _loadAppointments();
              },
            ),
            const SizedBox(height: 12),

            // 2) Timeslot list
            Expanded(
              child: ListView.builder(
                itemCount: _timeSlots.length,
                itemBuilder: (ctx, i) {
                  final slot = _timeSlots[i];
                  final slotAppointments = _appointmentsForDate.where((a) {
                    return a.dateTime.hour == slot.hour &&
                        a.dateTime.minute == slot.minute;
                  }).toList();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          // Fixed-width, right-aligned time
                          SizedBox(
                            width: 80,
                            child: Text(
                              slot.format(context),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: slotAppointments.isEmpty
                                    ? Colors.grey[600]
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Slot details: multiple patients or “No one booked”
                          Expanded(
                            child: slotAppointments.isEmpty
                                ? Text(
                                    'No one booked',
                                    style: TextStyle(
                                        color: Colors.grey[600]),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: slotAppointments.map((a) {
                                      final pat =
                                          _findPatient(a.patientId);
                                      final name = pat != null
                                          ? '${pat.firstName} ${pat.lastName}'
                                          : 'Unknown';
                                      return Padding(
                                        padding: const EdgeInsets
                                                .symmetric(
                                            vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(name)),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete,
                                                  size: 20),
                                              onPressed: () =>
                                                  _deleteAppointment(
                                                      a.id!),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),

                          // Always-visible “add” button
                          IconButton(
                            icon: const Icon(
                                Icons.add_circle_outline),
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            onPressed: () =>
                                _showAddAppointmentDialog(slot),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
