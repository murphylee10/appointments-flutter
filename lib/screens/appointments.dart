import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

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
          (p.email?.toLowerCase().contains(q) ?? false) ||
          (p.phone?.toLowerCase().contains(q) ?? false);
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
  int _defaultDuration = 40;

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
    final db = DatabaseHelper();
    final all = await db.getAppointments();
    final settings = await db.getAllSettings();
    _defaultDuration = int.tryParse(settings[SettingsKeys.defaultAppointmentDuration] ?? '40') ?? 40;
    _appointmentsForDate = all
        .where((a) => _sameDate(a.dateTime, _selectedDate))
        .toList();
    // Sort by start time
    _appointmentsForDate.sort((a, b) => a.dateTime.compareTo(b.dateTime));
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

  /// Compute end time from start time + duration
  TimeOfDay _computeEndTime(TimeOfDay start, int durationMinutes) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = startMinutes + durationMinutes;
    return TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
  }

  Future<void> _showAddAppointmentDialog() async {
    List<Patient> selectedPatients = [];
    final notesController = TextEditingController();
    final priceController = TextEditingController();
    final serviceDescController = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay endTime = _computeEndTime(startTime, _defaultDuration);

    // Load default price and service description
    final settings = await DatabaseHelper().getAllSettings();
    priceController.text = settings[SettingsKeys.unitPrice] ?? '40.0';
    serviceDescController.text = settings[SettingsKeys.serviceDescription] ?? 'Chiropractic adjustment';

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Appointment'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected patients as chips
                if (selectedPatients.isNotEmpty) ...[
                  Text(
                    'Patients',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: selectedPatients.map((p) => Chip(
                      label: Text(
                        '${p.firstName} ${p.lastName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setDialogState(() => selectedPatients.remove(p)),
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Add patient button
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(selectedPatients.isEmpty ? 'Add Patient' : 'Add Another Patient'),
                  onPressed: () async {
                    final result = await showSearch<Patient?>(
                      context: context,
                      delegate: PatientSearchDelegate(_allPatients),
                    );
                    if (result != null && !selectedPatients.any((p) => p.id == result.id)) {
                      setDialogState(() => selectedPatients.add(result));
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Time pickers row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startTime = picked;
                              endTime = _computeEndTime(picked, _defaultDuration);
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            suffixIcon: Icon(Icons.access_time, size: 20),
                          ),
                          child: Text(startTime.format(context)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 20),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              endTime = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            suffixIcon: Icon(Icons.access_time, size: 20),
                          ),
                          child: Text(endTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Notes field
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),

                // Price and service description row
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: serviceDescController,
                        decoration: const InputDecoration(
                          labelText: 'Service Description',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: selectedPatients.isEmpty
                  ? null
                  : () async {
                      final startDt = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        startTime.hour,
                        startTime.minute,
                      );
                      final endDt = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        endTime.hour,
                        endTime.minute,
                      );
                      // Parse price
                      final price = double.tryParse(priceController.text);

                      // Create appointment for each selected patient
                      for (final patient in selectedPatients) {
                        await DatabaseHelper().insertAppointment(
                          Appointment(
                            patientId: patient.id!,
                            dateTime: startDt,
                            endDateTime: endDt,
                            notes: notesController.text,
                            price: price,
                            serviceDescription: serviceDescController.text,
                          ),
                        );
                      }
                      Navigator.pop(context);
                      _loadAppointments();
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Format time range for display
  String _formatTimeRange(Appointment a) {
    final startStr = TimeOfDay.fromDateTime(a.dateTime).format(context);
    if (a.endDateTime != null) {
      final endStr = TimeOfDay.fromDateTime(a.endDateTime!).format(context);
      return '$startStr - $endStr';
    }
    return startStr;
  }

  /// Add another person to an existing time slot
  Future<void> _addPersonToSlot(Appointment existingAppt) async {
    int? selectedPatientId;
    final patientController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Person to Slot'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show time slot (read-only)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _formatTimeRange(existingAppt),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Patient search field
                TextFormField(
                  controller: patientController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Patient',
                    hintText: 'Search patient…',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onTap: () async {
                    final result = await showSearch<Patient?>(
                      context: context,
                      delegate: PatientSearchDelegate(_allPatients),
                    );
                    if (result != null) {
                      selectedPatientId = result.id!;
                      patientController.text = '${result.firstName} ${result.lastName}';
                      setDialogState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: selectedPatientId == null
                  ? null
                  : () async {
                      await DatabaseHelper().insertAppointment(
                        Appointment(
                          patientId: selectedPatientId!,
                          dateTime: existingAppt.dateTime,
                          endDateTime: existingAppt.endDateTime,
                          notes: '',
                          price: existingAppt.price,
                          serviceDescription: existingAppt.serviceDescription,
                        ),
                      );
                      Navigator.pop(context);
                      _loadAppointments();
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // 1) Calendar picker
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (d) {
                    _selectedDate = d;
                    _loadAppointments();
                  },
                ),
              ),
            ),

            // 2) Header with date and Add button
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddAppointmentDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Appointment'),
                    ),
                  ],
                ),
              ),
            ),

            // 3) Appointments list or empty state
            Expanded(
              child: _appointmentsForDate.isEmpty
                  ? _buildEmptyState()
                  : _buildAppointmentsList(primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No appointments scheduled',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'for ${DateFormat.yMMMd().format(_selectedDate)}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(Color primaryColor) {
    // Sort appointments by start time
    final sorted = List<Appointment>.from(_appointmentsForDate)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        return _buildAppointmentCard(sorted[i], primaryColor);
      },
    );
  }

  Widget _buildAppointmentCard(Appointment appointment, Color primaryColor) {
    final patient = _findPatient(appointment.patientId);
    final patientName = patient != null
        ? '${patient.firstName} ${patient.lastName}'
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: primaryColor,
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        child: Row(
          children: [
            // Time range
            SizedBox(
              width: 140,
              child: Text(
                _formatTimeRange(appointment),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Patient name and notes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (appointment.notes.isNotEmpty)
                    Text(
                      appointment.notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Add person button (creates another appointment at same time)
            IconButton(
              icon: const Icon(Icons.person_add_outlined, size: 20),
              tooltip: 'Add Person to Slot',
              onPressed: () => _addPersonToSlot(appointment),
            ),

            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete Appointment',
              onPressed: () => _deleteAppointment(appointment.id!),
            ),
          ],
        ),
      ),
    );
  }
}
