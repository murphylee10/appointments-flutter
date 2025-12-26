import 'package:appt_flutter/models/series.dart';
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
          'phone TEXT, '
          'address TEXT'
          ')',
        );
        await db.execute(
          'CREATE TABLE appointments('
          'id INTEGER PRIMARY KEY, '
          'patient_id INTEGER, '
          'datetime TEXT, '
          'notes TEXT, '
          'paid INTEGER DEFAULT 0, '
          'series_id INTEGER, '
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
        await db.execute('''
          CREATE TABLE series(
            id INTEGER PRIMARY KEY,
            patient_id INTEGER,
            start_datetime TEXT,
            frequency TEXT,
            end_date TEXT,
            FOREIGN KEY(patient_id) REFERENCES patients(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE groups(
            id INTEGER PRIMARY KEY,
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE group_members(
            group_id INTEGER,
            patient_id INTEGER,
            PRIMARY KEY(group_id, patient_id),
            FOREIGN KEY(group_id) REFERENCES groups(id),
            FOREIGN KEY(patient_id) REFERENCES patients(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE patients ADD COLUMN address TEXT');
        }
      },
      version: 2,
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
        firstName: maps[i]['first_name'] ?? '',
        middleName: maps[i]['middle_name'],
        lastName: maps[i]['last_name'] ?? '',
        gender: maps[i]['gender'],
        dob: maps[i]['dob'],
        email: maps[i]['email'],
        phone: maps[i]['phone'],
        address: maps[i]['address'],
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

  Future<List<Appointment>> getAppointmentsByPatientId(int patientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'appointments',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'datetime DESC',
    );
    return maps.map((row) => Appointment.fromMap(row)).toList();
  }

  Future<List<Series>> getSeriesByPatientId(int patientId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'series',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'start_datetime DESC',
    );
    return maps.map((row) => Series.fromMap(row)).toList();
  }

  Future<List<Receipt>> getReceiptsByPatientId(int patientId) async {
    final db = await database;
    final recRows = await db.query(
      'receipts',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'datetime DESC',
    );
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
  ///  Recurring: create a series + its appointments
  Future<void> createSeriesAndAppointments({ required Series series }) async {
    final db = await database;
    await db.transaction((txn) async {
      final sid = await txn.insert('series', series.toMap());
      DateTime dt = series.startDateTime;
      final limit = series.endDate ?? dt.add(const Duration(days:365*5));
      final delta = series.frequency == 'BIWEEKLY'
        ? const Duration(days:14)
        : const Duration(days:7);
      while (!dt.isAfter(limit)) {
        await txn.insert('appointments', {
          'patient_id': series.patientId,
          'datetime': dt.toIso8601String(),
          'notes': '',
          'paid': 0,
          'series_id': sid,
        });
        dt = dt.add(delta);
      }
    });
  }

  ///  Cancel a series from a given date onward
  Future<void> cancelSeriesFrom(int seriesId, DateTime from) async {
    final db = await database;
    await db.delete(
      'appointments',
      where: 'series_id = ? AND datetime >= ?',
      whereArgs: [seriesId, from.toIso8601String()],
    );
  }

}

