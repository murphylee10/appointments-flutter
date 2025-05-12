import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../utils/receipt_helper.dart';


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
        // Keep the AppBar white if you like, but buttons must be dark:
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing) ...[
            TextButton(
              onPressed: () => setState(() => _editing = false),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary, // dark text
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saveChanges,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary, // dark text
              ),
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
      body: ListView(
        children: years.map((year) {
          final appts = _byYear[year]!;
          return ExpansionTile(
            key: PageStorageKey(year),
            title: Text('$year'),
            initiallyExpanded: year == _currentYear,
            children: appts.map((a) {
              final paid = _paidMap[a.id] ?? false;
              final dateStr = DateFormat.yMMMd().format(a.dateTime);
              final timeStr = TimeOfDay.fromDateTime(a.dateTime).format(context);
              return ListTile(
                title: Text('$dateStr @ $timeStr'),
                trailing: Checkbox(
                  value: paid,
                  onChanged: _editing
                      ? (v) => setState(() => _paidMap[a.id!] = v!)
                      : null,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
