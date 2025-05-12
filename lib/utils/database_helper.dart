import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/receipt.dart';

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
          'paid INTEGER DEFAULT 0, '
          'FOREIGN KEY(patient_id) REFERENCES patients(id)'
          ')',
        );
        await db.execute('''
          CREATE TABLE receipts(
            id INTEGER PRIMARY KEY,
            patient_id INTEGER,
            datetime TEXT,
            file_path TEXT,
            FOREIGN KEY(patient_id) REFERENCES patients(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE receipt_items(
            id INTEGER PRIMARY KEY,
            receipt_id INTEGER,
            appointment_id INTEGER,
            FOREIGN KEY(receipt_id) REFERENCES receipts(id) ON DELETE CASCADE,
            FOREIGN KEY(appointment_id) REFERENCES appointments(id)
          )
        ''');
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
    return maps.map((row) => Appointment.fromMap(row)).toList();
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

  Future<void> updateAppointmentPaid(int id, bool paid) async {
    final db = await database;
    await db.update(
      'appointments',
      {'paid': paid ? 1 : 0},
      where: 'id = ?', whereArgs: [id],
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

  Future<int> insertReceipt(Receipt receipt) async {
    final db = await database;
    return await db.transaction((txn) async {
      final rid = await txn.insert('receipts', {
        'patient_id': receipt.patientId,
        'datetime': receipt.dateTime.toIso8601String(),
        'file_path': receipt.filePath,
      });
      for (var aid in receipt.appointmentIds) {
        await txn.insert('receipt_items', {
          'receipt_id': rid,
          'appointment_id': aid,
        });
      }
      return rid;
    });
  }

  Future<List<Receipt>> getReceipts() async {
    final db = await database;
    final recRows = await db.query('receipts', orderBy: 'datetime DESC');
    final List<Receipt> list = [];
    for (var row in recRows) {
      final rid = row['id'] as int;
      final items = await db.query(
        'receipt_items',
        columns: ['appointment_id'],
        where: 'receipt_id = ?',
        whereArgs: [rid],
      );
      final aids = items.map((r) => r['appointment_id'] as int).toList();
      list.add(Receipt.fromMap(row, aids));
    }
    return list;
  }
}
