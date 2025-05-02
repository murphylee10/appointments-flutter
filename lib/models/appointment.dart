class Appointment {
  final int? id;
  final int patientId;
  final DateTime dateTime;
  final String notes;

  Appointment({
    this.id,
    required this.patientId,
    required this.dateTime,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'datetime': dateTime.toIso8601String(),
      'notes': notes,
    };
  }

  @override
  String toString() {
    return 'Appointment{id: $id, patientId: $patientId, dateTime: $dateTime, notes: $notes}';
  }
}
