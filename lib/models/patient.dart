class Patient {
  final int? id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String dob; // Store date as a string for simplicity
  final String email;
  final String phone;

  Patient({
    this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
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
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
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
    return 'Patient{id: $id, firstName: $firstName, middleName: $middleName, lastName: $lastName, gender: $gender, dob: $dob, email: $email, phone: $phone}';
  }
}
