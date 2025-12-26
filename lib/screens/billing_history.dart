import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../utils/receipt_helper.dart';
import '../theme/app_theme.dart';


/// Full-screen billing history with grouping, edit/save, and receipt export
class BillingHistoryPage extends StatefulWidget {
  final Patient patient;
  const BillingHistoryPage({required this.patient, super.key});

  @override
  _BillingHistoryPageState createState() => _BillingHistoryPageState();
}

class _BillingHistoryPageState extends State<BillingHistoryPage> {
  final db = DatabaseHelper();
  List<Appointment> _history = [];
  bool _editing = false;
  late Map<int,bool> _paidMap; // appointment.id → paid flag

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final all = await db.getAppointments();
    _history = all.where((a) => a.patientId == widget.patient.id).toList();
    _paidMap = { for (var a in _history) a.id!: a.paid };
    setState(() {});
  }

  int get _currentYear => DateTime.now().year;

  Map<int,List<Appointment>> get _byYear {
    final map = <int,List<Appointment>>{};
    for (var a in _history) {
      map.putIfAbsent(a.dateTime.year, () => []).add(a);
    }
    return map;
  }

  Future<void> _saveChanges() async {
    for (var a in _history) {
      final newPaid = _paidMap[a.id] ?? false;
      if (newPaid != a.paid) {
        await db.updateAppointmentPaid(a.id!, newPaid);
      }
    }
    _editing = false;
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    // Sort years descending
    final years = _byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patient.firstName} ${widget.patient.lastName} History'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Payment Status',
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing) ...[
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Save'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Receipt',
            onPressed: () {
              ReceiptHelper.generateHtmlReceipt(
                context: context,
                patient: widget.patient,
                appointments: _history.where((a) => !(_paidMap[a.id] ?? false)).toList(),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Card(
          child: ListView(
            children: years.map((year) {
              final appts = _byYear[year]!;
              final paidCount = appts.where((a) => _paidMap[a.id] ?? false).length;
              return ExpansionTile(
                key: PageStorageKey(year),
                title: Text(
                  '$year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${appts.length} appointments • $paidCount paid',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                initiallyExpanded: year == _currentYear,
                children: appts.map((a) {
                  final paid = _paidMap[a.id] ?? false;
                  final dateStr = DateFormat.yMMMd().format(a.dateTime);
                  final timeStr = TimeOfDay.fromDateTime(a.dateTime).format(context);
                  return ListTile(
                    title: Text('$dateStr @ $timeStr'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: paid
                                ? AppColors.successGreen.withOpacity(0.1)
                                : AppColors.warningAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            paid ? 'Paid' : 'Unpaid',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: paid ? AppColors.successGreen : AppColors.warningAmber,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Checkbox(
                          value: paid,
                          onChanged: _editing
                              ? (v) => setState(() => _paidMap[a.id!] = v!)
                              : null,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
