import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/series.dart';
import '../models/receipt.dart';
import '../utils/database_helper.dart';
import '../utils/receipt_helper.dart';
import '../theme/app_theme.dart';
import 'billing_history.dart';

class PatientProfileScreen extends StatefulWidget {
  final Patient patient;

  const PatientProfileScreen({required this.patient, super.key});

  @override
  _PatientProfileScreenState createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late Patient _patient;
  List<Appointment> _appointments = [];
  List<Series> _series = [];
  List<Receipt> _receipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final appointments = await db.getAppointmentsByPatientId(_patient.id!);
    final series = await db.getSeriesByPatientId(_patient.id!);
    final receipts = await db.getReceiptsByPatientId(_patient.id!);
    setState(() {
      _appointments = appointments;
      _series = series;
      _receipts = receipts;
      _loading = false;
    });
  }

  /// Get active series (end date is null or in the future)
  List<Series> get _activeSeries {
    final now = DateTime.now();
    return _series.where((s) => s.endDate == null || s.endDate!.isAfter(now)).toList();
  }

  /// Get unpaid appointments
  List<Appointment> get _unpaidAppointments {
    return _appointments.where((a) => !a.paid).toList();
  }

  /// Get first visit date formatted
  String _getFirstVisitDate() {
    if (_appointments.isEmpty) return 'N/A';
    final sorted = List<Appointment>.from(_appointments)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return DateFormat.yMMMd().format(sorted.first.dateTime);
  }

  /// Get last visit date formatted
  String _getLastVisitDate() {
    if (_appointments.isEmpty) return 'N/A';
    final sorted = List<Appointment>.from(_appointments)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return DateFormat.yMMMd().format(sorted.last.dateTime);
  }

  /// Schedule a new appointment for this patient
  Future<void> _scheduleAppointment() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Appointment'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient: ${_patient.firstName} ${_patient.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                // Time picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  subtitle: Text(selectedTime.format(context)),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final dateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      await DatabaseHelper().insertAppointment(
        Appointment(
          patientId: _patient.id!,
          dateTime: dateTime,
          notes: '',
        ),
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment scheduled for ${DateFormat.yMMMd().format(dateTime)} @ ${selectedTime.format(context)}',
            ),
          ),
        );
      }
    }
  }

  /// Generate receipt for unpaid appointments
  Future<void> _generateReceipt() async {
    final unpaid = _unpaidAppointments;
    if (unpaid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unpaid appointments to include in receipt')),
      );
      return;
    }

    await ReceiptHelper.generateHtmlReceipt(
      context: context,
      patient: _patient,
      appointments: unpaid,
    );
    await _loadData(); // Reload to show new receipt
  }

  /// Calculate age from DOB string
  int? _calculateAge(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  /// Format DOB for display
  String _formatDob(String? dob) {
    if (dob == null || dob.isEmpty) return 'Not provided';
    try {
      final date = DateTime.parse(dob);
      return DateFormat.yMMMd().format(date);
    } catch (_) {
      return dob;
    }
  }

  /// Get gender display text
  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return 'Not specified';
    switch (gender.toUpperCase()) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      default:
        return gender;
    }
  }

  Future<void> _showEditDialog() async {
    final fk = GlobalKey<FormState>();
    final fn = TextEditingController(text: _patient.firstName);
    final mn = TextEditingController(text: _patient.middleName);
    final ln = TextEditingController(text: _patient.lastName);
    String? gender = _patient.gender?.isNotEmpty == true ? _patient.gender : null;
    final dob = TextEditingController(
      text: _patient.dob?.isNotEmpty == true
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(_patient.dob!))
          : '',
    );
    final email = TextEditingController(text: _patient.email);
    final phone = TextEditingController(text: _patient.phone);
    final address = TextEditingController(text: _patient.address);

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Edit Patient'),
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
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['M', 'F']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => gender = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: dob,
                      decoration: const InputDecoration(labelText: 'Date of Birth'),
                      readOnly: true,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _patient.dob?.isNotEmpty == true
                              ? DateTime.parse(_patient.dob!)
                              : DateTime(2000, 1, 1),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) {
                          dob.text = DateFormat('yyyy-MM-dd').format(d);
                          setDialogState(() {});
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: () async {
                if (!fk.currentState!.validate()) return;
                final updated = Patient(
                  id: _patient.id,
                  firstName: fn.text,
                  middleName: mn.text.isEmpty ? null : mn.text,
                  lastName: ln.text,
                  gender: gender,
                  dob: dob.text.isEmpty ? null : dob.text,
                  email: email.text.isEmpty ? null : email.text,
                  phone: phone.text.isEmpty ? null : phone.text,
                  address: address.text.isEmpty ? null : address.text,
                );
                await DatabaseHelper().updatePatient(updated);
                Navigator.pop(context);
                setState(() {
                  _patient = updated;
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
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
                text: '${_patient.firstName} ${_patient.lastName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: '? This will also delete all their appointments.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
      await DatabaseHelper().deletePatient(_patient.id!);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge(_patient.dob);
    final fullName = [
      _patient.firstName,
      if (_patient.middleName != null && _patient.middleName!.isNotEmpty)
        _patient.middleName,
      _patient.lastName,
    ].join(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Patient',
            onPressed: _showEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Patient',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    // Avatar placeholder
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        _patient.firstName.isNotEmpty
                            ? _patient.firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    // Name and basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              if (age != null) ...[
                                Text(
                                  '$age years old',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                              ],
                              if (_patient.gender?.isNotEmpty == true)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(
                                    _patient.gender!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quick contact icons
                    if (_patient.phone?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.phone),
                        tooltip: _patient.phone,
                        onPressed: () {
                          // Could launch phone dialer in future
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Phone: ${_patient.phone}')),
                          );
                        },
                      ),
                    if (_patient.email?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.email),
                        tooltip: _patient.email,
                        onPressed: () {
                          // Could launch email client in future
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Email: ${_patient.email}')),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Quick Actions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _scheduleAppointment,
                            icon: const Icon(Icons.add_circle, size: 20),
                            label: const Text('Schedule Appointment'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _unpaidAppointments.isEmpty ? null : _generateReceipt,
                            icon: const Icon(Icons.receipt_long, size: 20),
                            label: Text(
                              _unpaidAppointments.isEmpty
                                  ? 'No Unpaid Visits'
                                  : 'Generate Receipt (${_unpaidAppointments.length})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Patient Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildInfoRow('Date of Birth', _formatDob(_patient.dob)),
                    _buildInfoRow('Gender', _formatGender(_patient.gender)),
                    _buildInfoRow(
                      'Email',
                      _patient.email?.isNotEmpty == true ? _patient.email! : 'Not provided',
                    ),
                    _buildInfoRow(
                      'Phone',
                      _patient.phone?.isNotEmpty == true ? _patient.phone! : 'Not provided',
                    ),
                    _buildInfoRow(
                      'Address',
                      _patient.address?.isNotEmpty == true ? _patient.address! : 'Not provided',
                    ),
                    if (!_loading && _appointments.isNotEmpty) ...[
                      _buildInfoRow('First Visit', _getFirstVisitDate()),
                      _buildInfoRow('Last Visit', _getLastVisitDate()),
                    ],
                  ],
                ),
              ),
            ),

            // Appointment Summary Card
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Appointment Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BillingHistoryPage(patient: _patient),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('Full History'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_appointments.isEmpty)
                      Text(
                        'No appointments yet',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      _buildAppointmentSummary(),
                  ],
                ),
              ),
            ),

            // Active Series Card
            if (!_loading && _activeSeries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Recurring Series',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ..._activeSeries.map((series) => _buildSeriesItem(series)),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Receipts Card
            if (!_loading && _receipts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Receipts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._receipts.take(3).map((receipt) => _buildReceiptItem(receipt)),
                    ],
                  ),
                ),
              ),
            ],

            // Recent Appointments Card
            if (!_loading && _appointments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Appointments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._buildRecentAppointmentsList(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentSummary() {
    final total = _appointments.length;
    final paidCount = _appointments.where((a) => a.paid).length;
    final unpaidCount = total - paidCount;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryTile(
            icon: Icons.event,
            label: 'Total Visits',
            value: total.toString(),
          ),
        ),
        Expanded(
          child: _buildSummaryTile(
            icon: Icons.check_circle,
            label: 'Paid',
            value: paidCount.toString(),
            valueColor: AppColors.successGreen,
          ),
        ),
        Expanded(
          child: _buildSummaryTile(
            icon: Icons.pending,
            label: 'Unpaid',
            value: unpaidCount.toString(),
            valueColor: unpaidCount > 0 ? AppColors.warningAmber : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRecentAppointmentsList() {
    // Show up to 5 most recent (already sorted DESC from query)
    final recent = _appointments.take(5).toList();

    return recent.map((appointment) {
      final dateStr = DateFormat.yMMMd().format(appointment.dateTime);
      final timeStr = TimeOfDay.fromDateTime(appointment.dateTime).format(context);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dateStr @ $timeStr',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (appointment.notes.isNotEmpty)
                    Text(
                      appointment.notes.length > 50
                          ? '${appointment.notes.substring(0, 50)}...'
                          : appointment.notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: appointment.paid
                    ? AppColors.successGreen.withOpacity(0.1)
                    : AppColors.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                appointment.paid ? 'Paid' : 'Unpaid',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: appointment.paid
                      ? AppColors.successGreen
                      : AppColors.warningAmber,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesItem(Series series) {
    final frequencyText = series.frequency == 'WEEKLY' ? 'Weekly' : 'Biweekly';
    final startDate = DateFormat.yMMMd().format(series.startDateTime);
    final endDate = series.endDate != null
        ? DateFormat.yMMMd().format(series.endDate!)
        : 'Ongoing';

    // Find next upcoming appointment in this series
    final now = DateTime.now();
    final upcomingInSeries = _appointments
        .where((a) => a.seriesId == series.id && a.dateTime.isAfter(now))
        .toList();
    upcomingInSeries.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final nextAppointment = upcomingInSeries.isNotEmpty ? upcomingInSeries.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.repeat,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$frequencyText Appointments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Started: $startDate',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Ends: $endDate',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (nextAppointment != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.infoBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Next: ${DateFormat.yMMMd().format(nextAppointment.dateTime)} @ ${TimeOfDay.fromDateTime(nextAppointment.dateTime).format(context)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.infoBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptItem(Receipt receipt) {
    final dateStr = DateFormat.yMMMd().format(receipt.dateTime);
    final appointmentCount = receipt.appointmentIds.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt #${receipt.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$dateStr • $appointmentCount appointment${appointmentCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
