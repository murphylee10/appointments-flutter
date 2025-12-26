class Series {
  final int? id;
  final int patientId;
  final DateTime startDateTime;
  final String frequency;    // 'WEEKLY' or 'BIWEEKLY'
  final DateTime? endDate;   // null = no end

  Series({
    this.id,
    required this.patientId,
    required this.startDateTime,
    required this.frequency,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'start_datetime': startDateTime.toIso8601String(),
      'frequency': frequency,
      'end_date': endDate?.toIso8601String(),
    };
  }

  factory Series.fromMap(Map<String, dynamic> m) {
    return Series(
      id: m['id'] as int?,
      patientId: m['patient_id'] as int,
      startDateTime: DateTime.parse(m['start_datetime'] as String),
      frequency: m['frequency'] as String,
      endDate: m['end_date'] != null
          ? DateTime.parse(m['end_date'] as String)
          : null,
    );
  }
}
