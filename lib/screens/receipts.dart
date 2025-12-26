import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../models/receipt.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../theme/app_theme.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final db = DatabaseHelper();
  List<Receipt> _receipts = [];
  Map<int, Patient> _patients = {};
  Map<int, Appointment> _appointments = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final recs = await db.getReceipts();
    final pats = await db.getPatients();
    final appts = await db.getAppointments();
    setState(() {
      _receipts = recs;
      _patients = { for (var p in pats) p.id!: p };
      _appointments = { for (var a in appts) a.id!: a };
    });
  }

  Future<void> _markPaid(Receipt r) async {
    for (var aid in r.appointmentIds) {
      await db.updateAppointmentPaid(aid, true);
    }
    _loadAll();
  }

  Future<void> _clearAllReceipts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
            const SizedBox(width: AppSpacing.sm),
            const Text('Clear All Receipts?'),
          ],
        ),
        content: const Text('This will delete every receipt record. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final database = await db.database;
      await database.delete('receipts'); // cascades to receipt_items
      setState(() {
        _receipts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All receipts cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Receipts',
            onPressed: _clearAllReceipts,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Card(
          child: ListView.builder(
            itemCount: _receipts.length,
            itemBuilder: (ctx, i) {
              final r = _receipts[i];
              final p = _patients[r.patientId];
              final genDate = DateFormat.yMMMd().add_jm().format(r.dateTime);
              final unpaidExists = r.appointmentIds.any((aid) => _appointments[aid]?.paid == false);

              return ExpansionTile(
                title: Text(
                  'Receipt ${r.id} – ${p?.firstName} ${p?.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Generated: $genDate',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                children: [
                  // Section header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Appointments:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  // List of appointments
                  ...r.appointmentIds.map((aid) {
                    final a = _appointments[aid]!;
                    final date = DateFormat.yMMMd().format(a.dateTime);
                    final time = TimeOfDay.fromDateTime(a.dateTime).format(context);
                    return ListTile(
                      title: Text('$date @ $time'),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: a.paid
                              ? AppColors.successGreen.withOpacity(0.1)
                              : AppColors.warningAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          a.paid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: a.paid ? AppColors.successGreen : AppColors.warningAmber,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Bulk mark-paid button
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: unpaidExists ? () => _markPaid(r) : null,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('Mark All as Paid'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
