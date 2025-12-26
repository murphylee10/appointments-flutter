class Group {
  final int? id;
  final String name;

  Group({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}
