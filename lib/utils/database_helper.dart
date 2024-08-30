import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'chiropractic_app.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE patients(id INTEGER PRIMARY KEY, full_name TEXT, gender TEXT, dob TEXT, email TEXT, phone TEXT)',
        );
      },
      version: 1,
    );
  }

  // Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /* PATIENT CRUD */
  Future<void> insertPatient(Patient patient) async {
    final db = await database;

    await db.insert(
      'patients',
      patient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Patient>> getPatients() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('patients');

    return List.generate(maps.length, (i) {
      return Patient(
        id: maps[i]['id'],
        fullName: maps[i]['full_name'],
        gender: maps[i]['gender'],
        dob: maps[i]['dob'],
        email: maps[i]['email'],
        phone: maps[i]['phone'],
      );
    });
  }

  Future<void> updatePatient(Patient patient) async {
    final db = await database;

    await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<void> deletePatient(int id) async {
    final db = await database;

    await db.delete(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
