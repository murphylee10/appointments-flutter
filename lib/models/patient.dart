class Patient {
  final int? id;
  final String fullName;
  final String gender;
  final String dob; // Store date as a string for simplicity
  final String email;
  final String phone;

  Patient({
    this.id,
    required this.fullName,
    required this.gender,
    required this.dob,
    required this.email,
    required this.phone,
  });

  // Convert a Patient into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'gender': gender,
      'dob': dob,
      'email': email,
      'phone': phone,
    };
  }

  // Implement toString to make it easier to see information about
  // each patient when using the print statement.
  @override
  String toString() {
    return 'Patient{id: $id, fullName: $fullName, gender: $gender, dob: $dob, email: $email, phone: $phone}';
  }
}
