import 'dart:io';
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

  // Pagination
  static const int _pageSize = 5;
  int _receiptsPage = 0;
  int _appointmentsPage = 0;

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

  // Pagination helpers for receipts
  List<Receipt> get _paginatedReceipts {
    final start = _receiptsPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _receipts.length);
    if (start >= _receipts.length) return [];
    return _receipts.sublist(start, end);
  }

  int get _totalReceiptPages => (_receipts.length / _pageSize).ceil().clamp(1, 999);

  // Pagination helpers for appointments
  List<Appointment> get _paginatedAppointments {
    final start = _appointmentsPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _appointments.length);
    if (start >= _appointments.length) return [];
    return _appointments.sublist(start, end);
  }

  int get _totalAppointmentPages => (_appointments.length / _pageSize).ceil().clamp(1, 999);

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

  /// Compute end time from start time + duration
  TimeOfDay _computeEndTime(TimeOfDay start, int durationMinutes) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = startMinutes + durationMinutes;
    return TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
  }

  /// Schedule a new appointment for this patient
  Future<void> _scheduleAppointment() async {
    // Load settings for defaults
    final settings = await DatabaseHelper().getAllSettings();
    final defaultDuration = int.tryParse(settings[SettingsKeys.defaultAppointmentDuration] ?? '40') ?? 40;

    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay endTime = _computeEndTime(startTime, defaultDuration);
    final notesController = TextEditingController();
    final priceController = TextEditingController(
      text: settings[SettingsKeys.unitPrice] ?? '40.0',
    );
    final serviceDescController = TextEditingController(
      text: settings[SettingsKeys.serviceDescription] ?? 'Chiropractic adjustment',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Appointment'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
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
                  const SizedBox(height: AppSpacing.sm),
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
                                endTime = _computeEndTime(picked, defaultDuration);
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
      final startDt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startTime.hour,
        startTime.minute,
      );
      final endDt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        endTime.hour,
        endTime.minute,
      );
      final price = double.tryParse(priceController.text);
      await DatabaseHelper().insertAppointment(
        Appointment(
          patientId: _patient.id!,
          dateTime: startDt,
          endDateTime: endDt,
          notes: notesController.text,
          price: price,
          serviceDescription: serviceDescController.text,
        ),
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment scheduled for ${DateFormat.yMMMd().format(startDt)} @ ${startTime.format(context)}',
            ),
          ),
        );
      }
    }
  }

  /// Edit an existing appointment
  Future<void> _editAppointment(Appointment appointment) async {
    // Load default values from settings
    final settings = await DatabaseHelper().getAllSettings();
    final defaultPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '') ?? 40.0;
    final defaultServiceDesc = settings[SettingsKeys.serviceDescription] ?? 'Chiropractic adjustment';

    DateTime selectedDate = DateTime(
      appointment.dateTime.year,
      appointment.dateTime.month,
      appointment.dateTime.day,
    );
    TimeOfDay startTime = TimeOfDay.fromDateTime(appointment.dateTime);
    TimeOfDay endTime = appointment.endDateTime != null
        ? TimeOfDay.fromDateTime(appointment.endDateTime!)
        : _computeEndTime(startTime, 40);

    final notesController = TextEditingController(text: appointment.notes);
    final priceController = TextEditingController(
      text: (appointment.price ?? defaultPrice).toStringAsFixed(2),
    );
    final serviceDescController = TextEditingController(
      text: appointment.serviceDescription ?? defaultServiceDesc,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Appointment'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
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
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // Delete button on the left
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'delete'),
              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
              label: Text('Delete', style: TextStyle(color: AppColors.errorRed)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == 'save') {
      final startDt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startTime.hour,
        startTime.minute,
      );
      final endDt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        endTime.hour,
        endTime.minute,
      );
      final price = double.tryParse(priceController.text);
      final updated = Appointment(
        id: appointment.id,
        patientId: appointment.patientId,
        dateTime: startDt,
        endDateTime: endDt,
        notes: notesController.text,
        paid: appointment.paid,
        seriesId: appointment.seriesId,
        price: price,
        serviceDescription: serviceDescController.text,
      );
      await DatabaseHelper().updateAppointment(updated);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment updated to ${DateFormat.yMMMd().format(startDt)} @ ${startTime.format(context)}',
            ),
          ),
        );
      }
    } else if (result == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
              const SizedBox(width: AppSpacing.sm),
              const Text('Delete Appointment'),
            ],
          ),
          content: Text(
            'Delete the appointment on ${DateFormat.yMMMd().format(appointment.dateTime)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await DatabaseHelper().deleteAppointment(appointment.id!);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment deleted')),
          );
        }
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

    // Show selection dialog
    final selectedAppointments = await _showReceiptSelectionDialog(unpaid);
    if (selectedAppointments == null || selectedAppointments.isEmpty) {
      return; // User cancelled or selected nothing
    }

    await ReceiptHelper.generateHtmlReceipt(
      context: context,
      patient: _patient,
      appointments: selectedAppointments,
    );
    await _loadData(); // Reload to show new receipt
  }

  /// Show dialog to select which appointments to include in receipt
  Future<List<Appointment>?> _showReceiptSelectionDialog(List<Appointment> unpaid) async {
    // Load default price from settings (fallback for appointments without price)
    final settings = await DatabaseHelper().getAllSettings();
    final defaultPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '') ?? 40.0;

    // Sort by date descending (most recent first)
    final sorted = List<Appointment>.from(unpaid)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Track selection state - all selected by default
    final selected = Map<int, bool>.fromEntries(
      sorted.map((a) => MapEntry(a.id!, true)),
    );

    return showDialog<List<Appointment>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedCount = selected.values.where((v) => v).length;
          // Calculate total using individual appointment prices
          final total = sorted
              .where((a) => selected[a.id] == true)
              .fold<double>(0, (sum, a) => sum + (a.price ?? defaultPrice));

          return AlertDialog(
            title: const Text('Select Visits for Receipt'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select/Deselect All buttons
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            for (final id in selected.keys) {
                              selected[id] = true;
                            }
                          });
                        },
                        child: const Text('Select All'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            for (final id in selected.keys) {
                              selected[id] = false;
                            }
                          });
                        },
                        child: const Text('Deselect All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  // Scrollable list of checkboxes
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        children: sorted.map((appointment) {
                          final dateStr = DateFormat.yMMMd().format(appointment.dateTime);
                          final timeStr = DateFormat.jm().format(appointment.dateTime);
                          final price = appointment.price ?? defaultPrice;
                          return CheckboxListTile(
                            value: selected[appointment.id] ?? false,
                            onChanged: (value) {
                              setDialogState(() {
                                selected[appointment.id!] = value ?? false;
                              });
                            },
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$dateStr  $timeStr',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '\$${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),
                  // Running total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'Total: \$${total.toStringAsFixed(2)} ($selectedCount visit${selectedCount == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                onPressed: selectedCount > 0
                    ? () {
                        final result = sorted
                            .where((a) => selected[a.id] == true)
                            .toList();
                        Navigator.pop(context, result);
                      }
                    : null,
                child: const Text('Generate Receipt'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show receipt detail dialog with appointments, total, reprint/delete
  Future<void> _showReceiptDetailDialog(Receipt receipt) async {
    // Load default price from settings (fallback for appointments without price)
    final settings = await DatabaseHelper().getAllSettings();
    final defaultPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '') ?? 40.0;

    // Load appointment details for the receipt
    final receiptAppointments = _appointments
        .where((a) => receipt.appointmentIds.contains(a.id))
        .toList();
    receiptAppointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Calculate total using individual appointment prices
    final total = receiptAppointments.fold<double>(
      0,
      (sum, a) => sum + (a.price ?? defaultPrice),
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Receipt - ${DateFormat.yMMMd().format(receipt.dateTime)}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Text('Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Appointment rows
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: receiptAppointments.map((a) {
                      final price = a.price ?? defaultPrice;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                DateFormat.yMMMd().format(a.dateTime),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                DateFormat.jm().format(a.dateTime),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                '\$${price.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: AppSpacing.lg),
              // Total row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Mark as Paid button
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final db = DatabaseHelper();
              for (final appointment in receiptAppointments) {
                if (!appointment.paid) {
                  await db.updateAppointmentPaid(appointment.id!, true);
                }
              }
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${receiptAppointments.length} appointment${receiptAppointments.length == 1 ? '' : 's'} marked as paid'),
                  ),
                );
              }
            },
            icon: Icon(Icons.check_circle_outline, size: 18, color: AppColors.successGreen),
            label: Text('Mark as Paid', style: TextStyle(color: AppColors.successGreen)),
          ),
          // Reprint button
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final file = File(receipt.filePath);
                if (await file.exists()) {
                  await Process.run('cmd', ['/c', 'start', '', receipt.filePath]);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt file not found')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open receipt: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Reprint'),
          ),
          // Delete button
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Delete Receipt'),
                    ],
                  ),
                  content: Text('Delete this receipt from ${DateFormat.yMMMd().format(receipt.dateTime)}? The appointments will remain marked as paid.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await DatabaseHelper().deleteReceipt(receipt.id);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt deleted')),
                  );
                }
              }
            },
            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
            label: Text('Delete', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
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

            // Receipts Card (paginated)
            if (!_loading && _receipts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Receipts (${_receipts.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_totalReceiptPages > 1)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  onPressed: _receiptsPage > 0
                                      ? () => setState(() => _receiptsPage--)
                                      : null,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                Text(
                                  '${_receiptsPage + 1} / $_totalReceiptPages',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, size: 20),
                                  onPressed: _receiptsPage < _totalReceiptPages - 1
                                      ? () => setState(() => _receiptsPage++)
                                      : null,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._paginatedReceipts.map((receipt) => _buildReceiptItem(receipt)),
                    ],
                  ),
                ),
              ),
            ],

            // Appointments Card (paginated)
            if (!_loading && _appointments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Appointments (${_appointments.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_totalAppointmentPages > 1)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  onPressed: _appointmentsPage > 0
                                      ? () => setState(() => _appointmentsPage--)
                                      : null,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                Text(
                                  '${_appointmentsPage + 1} / $_totalAppointmentPages',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, size: 20),
                                  onPressed: _appointmentsPage < _totalAppointmentPages - 1
                                      ? () => setState(() => _appointmentsPage++)
                                      : null,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._buildPaginatedAppointmentsList(),
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

  List<Widget> _buildPaginatedAppointmentsList() {
    return _paginatedAppointments.map((appointment) {
      final dateStr = DateFormat.yMMMd().format(appointment.dateTime);
      final timeStr = TimeOfDay.fromDateTime(appointment.dateTime).format(context);

      return InkWell(
        onTap: () => _editAppointment(appointment),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
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
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
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

    return InkWell(
      onTap: () => _showReceiptDetailDialog(receipt),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
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
                    dateStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$appointmentCount appointment${appointmentCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
