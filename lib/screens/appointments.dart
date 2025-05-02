import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointmentsForDate = [];
  List<Patient> _allPatients = [];

  // Generate half-hour slots from 09:00 to 16:30
  static final List<TimeOfDay> _timeSlots = List.generate(
    16,
    (index) => TimeOfDay(
      hour: 9 + (index ~/ 2),
      minute: (index % 2) * 30,
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadAppointments();
  }

  Future<void> _loadPatients() async {
    final patients = await DatabaseHelper().getPatients();
    setState(() {
      _allPatients = patients;
    });
  }

  Future<void> _loadAppointments() async {
    final all = await DatabaseHelper().getAppointments();
    final filtered = all.where((a) => _sameDate(a.dateTime, _selectedDate)).toList();
    setState(() {
      _appointmentsForDate = filtered;
    });
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Patient? _findPatient(int id) {
    try {
      return _allPatients.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _showAddAppointmentDialog(TimeOfDay slot) async {
    final formKey = GlobalKey<FormState>();
    int? selectedPatientId;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('New Appointment – ${slot.format(context)}'),
          content: Form(
            key: formKey,
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Patient'),
              items: _allPatients.map((p) {
                return DropdownMenuItem(
                  value: p.id!,
                  child: Text('${p.firstName} ${p.lastName}'),
                );
              }).toList(),
              onChanged: (v) => selectedPatientId = v,
              validator: (v) => v == null ? 'Please select a patient' : null,
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
                final appt = Appointment(
                  patientId: selectedPatientId!,
                  dateTime: dt,
                  notes: '',
                );
                await DatabaseHelper().insertAppointment(appt);
                Navigator.pop(context);
                _loadAppointments();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar here—HomeScreen already provides one
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1) Date picker at the top
            CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              onDateChanged: (newDate) {
                setState(() => _selectedDate = newDate);
                _loadAppointments();
              },
            ),

            const SizedBox(height: 12),

            // 2) Timeslot list
            Expanded(
              child: ListView.builder(
                itemCount: _timeSlots.length,
                itemBuilder: (context, i) {
                  final slot = _timeSlots[i];

                  // Find any existing appointment at this time
                  Appointment? existing;
                  for (var a in _appointmentsForDate) {
                    if (a.dateTime.hour == slot.hour &&
                        a.dateTime.minute == slot.minute) {
                      existing = a;
                      break;
                    }
                  }

                  // Lookup the patient if booked
                  final patient = existing != null
                      ? _findPatient(existing.patientId)
                      : null;

                  return Card(
                    child: ListTile(
                      leading: Text(slot.format(context)),
                      title: Text(
                        existing != null
                            ? '${patient?.firstName ?? ''} ${patient?.lastName ?? ''}'
                            : 'Available',
                      ),
                      trailing: existing != null
                          ? IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                await DatabaseHelper()
                                    .deleteAppointment(existing!.id!);
                                _loadAppointments();
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _showAddAppointmentDialog(slot),
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
