import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/receipt.dart';

class ReceiptHelper {
  /// Prompts for a folder, writes the HTML receipt there,
  /// then records it in the `receipts` and `receipt_items` tables.
  static Future<void> generateHtmlReceipt({
    required BuildContext context,
    required Patient patient,
    required List<Appointment> appointments,
  }) async {
    // 1) Load settings from database
    final db = DatabaseHelper();
    final settings = await db.getAllSettings();
    final unitPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '') ?? 40.0;
    final clinicName = settings[SettingsKeys.clinicName] ?? 'Clinic';
    final addressLine1 = settings[SettingsKeys.addressLine1] ?? '';
    final addressLine2 = settings[SettingsKeys.addressLine2] ?? '';
    final serviceDescription = settings[SettingsKeys.serviceDescription] ?? 'Service';

    // 2) Let the user pick a folder
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a folder to save the receipt',
    );
    if (selectedDir == null) return; // user cancelled

    // 3) Build HTML
    final dateFormatter = DateFormat.yMMMd();
    final timeFormatter = DateFormat.jm();
    final total = appointments.length * unitPrice;

    final rows = appointments.map((a) {
      final d = dateFormatter.format(a.dateTime);
      final t = timeFormatter.format(a.dateTime);
      return '''
      <tr>
        <td>$d</td>
        <td>$t</td>
        <td>\$${unitPrice.toStringAsFixed(2)}</td>
        <td>$serviceDescription</td>
      </tr>
      ''';
    }).join();

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt for ${patient.firstName} ${patient.lastName}</title>
  <style>
    body { font-family: Arial; margin: 40px; color: #333; }
    h1 { margin-bottom: 0; }
    .address { color: #555; font-size: 0.9em; }
    .patient { margin: 20px 0; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
    th { background: #f9f9f9; }
    tfoot td { font-weight: bold; }
  </style>
</head>
<body>
  <h1>$clinicName</h1>
  <div class="address">
    $addressLine1<br>
    $addressLine2
  </div>
  <div class="patient">
    <strong>Patient:</strong> ${patient.firstName} ${patient.lastName}<br>
    <strong>Date:</strong> ${dateFormatter.format(DateTime.now())}
  </div>
  <table>
    <thead>
      <tr><th>Date</th><th>Time</th><th>Charge</th><th>Service</th></tr>
    </thead>
    <tbody>
      $rows
    </tbody>
    <tfoot>
      <tr>
        <td colspan="2">Total</td>
        <td colspan="2">\$${total.toStringAsFixed(2)}</td>
      </tr>
    </tfoot>
  </table>
</body>
</html>
''';

    // 4) Write file
    final fileName =
        'receipt_${patient.id}_${DateTime.now().millisecondsSinceEpoch}.html';
    final file = File('$selectedDir/$fileName');
    await file.writeAsString(html);

    // 5) Record in database
    final receipt = Receipt(
      id: 0, // dummy, will be replaced by insertReceipt
      patientId: patient.id!,
      dateTime: DateTime.now(),
      filePath: file.path,
      appointmentIds: appointments.map((a) => a.id!).toList(),
    );
    await db.insertReceipt(receipt);

    // 6) Feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt saved & recorded at ${file.path}')),
    );
  }
}
