class Appointment {
  final int? id;
  final int patientId;
  final DateTime dateTime;
  final String notes;
  final bool paid;

  Appointment({
    this.id,
    required this.patientId,
    required this.dateTime,
    required this.notes,
    this.paid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'datetime': dateTime.toIso8601String(),
      'notes': notes,
      'paid': paid ? 1 : 0,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> m) {
    return Appointment(
      id: m['id'],
      patientId: m['patient_id'],
      dateTime: DateTime.parse(m['datetime']),
      notes: m['notes'],
      paid: (m['paid'] as int) == 1,
    );
  }

  @override
  String toString() {
    return 'Appointment{id: $id, patientId: $patientId, dateTime: $dateTime, notes: $notes}';
  }
}
