import 'package:flutter/material.dart';

class Appointment {
  final int? id;
  final int patientId;
  final DateTime dateTime;
  final String notes;
  final bool paid;
  final int? seriesId;

  Appointment({
    this.id,
    required this.patientId,
    required this.dateTime,
    required this.notes,
    this.paid = false,
    this.seriesId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'datetime': dateTime.toIso8601String(),
      'notes': notes,
      'paid': paid ? 1 : 0,
      'series_id': seriesId,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> m) {
    return Appointment(
      id: m['id'] as int?,
      patientId: m['patient_id'] as int,
      dateTime: DateTime.parse(m['datetime'] as String),
      notes: m['notes'] as String,
      paid: (m['paid'] as int) == 1,
      seriesId: m['series_id'] as int?,
    );
  }

  @override
  String toString() {
    return 'Appointment{id: $id, patientId: $patientId, dateTime: $dateTime, notes: $notes, paid: $paid, seriesId: $seriesId}';
  }
}
