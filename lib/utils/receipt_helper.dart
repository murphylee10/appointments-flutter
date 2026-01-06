import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/database_helper.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/receipt.dart';

class ReceiptHelper {
  /// Opens a save dialog, writes the HTML receipt to the selected path,
  /// then records it in the `receipts` and `receipt_items` tables.
  static Future<void> generateHtmlReceipt({
    required BuildContext context,
    required Patient patient,
    required List<Appointment> appointments,
  }) async {
    // 1) Load settings from database (used as fallback for appointments without price/description)
    final db = DatabaseHelper();
    final settings = await db.getAllSettings();
    final defaultPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '') ?? 40.0;
    final clinicName = settings[SettingsKeys.clinicName] ?? 'Clinic';
    final addressLine1 = settings[SettingsKeys.addressLine1] ?? '';
    final addressLine2 = settings[SettingsKeys.addressLine2] ?? '';
    final clinicPhone = settings[SettingsKeys.clinicPhone] ?? '';
    final defaultServiceDescription = settings[SettingsKeys.serviceDescription] ?? 'Service';
    final receiptFooterText = settings[SettingsKeys.receiptFooterText] ?? '';

    // 2) Let the user pick save location
    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final patientName = '${patient.firstName} ${patient.lastName}';
    final defaultFileName = '$patientName - $timestamp.html';

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save receipt',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['html'],
    );
    if (savedPath == null) return; // user cancelled

    // 3) Build HTML
    final dateFormatter = DateFormat.yMMMd();

    // Calculate total using each appointment's individual price
    final total = appointments.fold<double>(
      0,
      (sum, a) => sum + (a.price ?? defaultPrice),
    );

    final rows = appointments.map((a) {
      final d = dateFormatter.format(a.dateTime);
      final price = a.price ?? defaultPrice;
      final serviceDesc = a.serviceDescription ?? defaultServiceDescription;
      return '''
      <tr>
        <td>$d</td>
        <td>\$${price.toStringAsFixed(2)}</td>
        <td>$serviceDesc</td>
      </tr>
      ''';
    }).join();

    // Build phone line only if provided
    final phoneLine = clinicPhone.isNotEmpty ? 'Tel: $clinicPhone<br>' : '';

    // Build footer section only if provided
    final footerSection = receiptFooterText.isNotEmpty
        ? '<div class="footer">$receiptFooterText</div>'
        : '';

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
    .footer { margin-top: 30px; color: #555; font-size: 1.1em; }
  </style>
</head>
<body>
  <h1>$clinicName</h1>
  <div class="address">
    $addressLine1<br>
    $addressLine2<br>
    $phoneLine
  </div>
  <div class="patient">
    <strong>Patient:</strong> ${patient.firstName} ${patient.lastName}<br>
    <strong>Date:</strong> ${dateFormatter.format(DateTime.now())}
  </div>
  <table>
    <thead>
      <tr><th>Date</th><th>Charge</th><th>Service</th></tr>
    </thead>
    <tbody>
      $rows
    </tbody>
    <tfoot>
      <tr>
        <td>Total</td>
        <td colspan="2">\$${total.toStringAsFixed(2)}</td>
      </tr>
    </tfoot>
  </table>
  $footerSection
</body>
</html>
''';

    // 4) Write file
    final file = File(savedPath);
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved & recorded at ${file.path}')),
      );
    }
  }
}
