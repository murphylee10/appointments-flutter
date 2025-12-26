class GroupMember {
  final int groupId;
  final int patientId;

  GroupMember({required this.groupId, required this.patientId});

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'patient_id': patientId,
    };
  }
}
