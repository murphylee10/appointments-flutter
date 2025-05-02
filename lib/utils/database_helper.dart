import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/appointment.dart';

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
    final path = join(await getDatabasesPath(), 'chiropractic_app.db');
    return openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE patients('
          'id INTEGER PRIMARY KEY, '
          'first_name TEXT, '
          'middle_name TEXT, '
          'last_name TEXT, '
          'gender TEXT, '
          'dob TEXT, '
          'email TEXT, '
          'phone TEXT'
          ')',
        );
        await db.execute(
          'CREATE TABLE appointments('
          'id INTEGER PRIMARY KEY, '
          'patient_id INTEGER, '
          'datetime TEXT, '
          'notes TEXT, '
          'FOREIGN KEY(patient_id) REFERENCES patients(id)'
          ')',
        );
      },
      version: 1,
    );
  }

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
        firstName: maps[i]['first_name'],
        middleName: maps[i]['middle_name'],
        lastName: maps[i]['last_name'],
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

  /* APPOINTMENT CRUD */
  Future<void> insertAppointment(Appointment appointment) async {
    final db = await database;
    await db.insert(
      'appointments',
      appointment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Appointment>> getAppointments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('appointments');
    return List.generate(maps.length, (i) {
      return Appointment(
        id: maps[i]['id'],
        patientId: maps[i]['patient_id'],
        dateTime: DateTime.parse(maps[i]['datetime']),
        notes: maps[i]['notes'],
      );
    });
  }

  Future<void> updateAppointment(Appointment appointment) async {
    final db = await database;
    await db.update(
      'appointments',
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
  }

  Future<void> deleteAppointment(int id) async {
    final db = await database;
    await db.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
