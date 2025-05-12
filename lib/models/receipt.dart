class Receipt {
  final int id;
  final int patientId;
  final DateTime dateTime;
  final String filePath;
  final List<int> appointmentIds;

  Receipt({
    required this.id,
    required this.patientId,
    required this.dateTime,
    required this.filePath,
    required this.appointmentIds,
  });

  factory Receipt.fromMap(Map<String, dynamic> m, List<int> apptIds) {
    return Receipt(
      id: m['id'] as int,
      patientId: m['patient_id'] as int,
      dateTime: DateTime.parse(m['datetime'] as String),
      filePath: m['file_path'] as String,
      appointmentIds: apptIds,
    );
  }
}
