import 'package:chirotrack/models/series.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/receipt.dart';

/// Settings keys for app configuration
class SettingsKeys {
  static const clinicName = 'clinic_name';
  static const addressLine1 = 'address_line1';
  static const addressLine2 = 'address_line2';
  static const unitPrice = 'unit_price';
  static const serviceDescription = 'service_description';
  static const defaultAppointmentDuration = 'default_appointment_duration';
  static const lastBackupDate = 'last_backup_date';
}

/// Default settings values (used on first launch)
const defaultSettings = {
  SettingsKeys.clinicName: 'Markham Chiropractic',
  SettingsKeys.addressLine1: '123 Main St.',
  SettingsKeys.addressLine2: 'Markham, ON L3R 1X5',
  SettingsKeys.unitPrice: '40.0',
  SettingsKeys.serviceDescription: 'Chiropractic adjustment',
  SettingsKeys.defaultAppointmentDuration: '40',
};

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
    final appDir = await getApplicationSupportDirectory();
    final dbPath = path.join(appDir.path, 'chiropractic_app.db');
    return openDatabase(
      dbPath,
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
          'end_datetime TEXT, '
          'notes TEXT, '
          'paid INTEGER DEFAULT 0, '
          'series_id INTEGER, '
          'price REAL, '
          'service_description TEXT, '
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
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        // Populate default settings
        for (final entry in defaultSettings.entries) {
          await db.insert('settings', {'key': entry.key, 'value': entry.value});
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE patients ADD COLUMN address TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE settings(
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
          // Populate default settings for existing databases
          for (final entry in defaultSettings.entries) {
            await db.insert('settings', {'key': entry.key, 'value': entry.value});
          }
        }
        if (oldVersion < 4) {
          // Add end_datetime column to appointments table
          await db.execute('ALTER TABLE appointments ADD COLUMN end_datetime TEXT');
          // Add default appointment duration setting
          await db.insert(
            'settings',
            {'key': SettingsKeys.defaultAppointmentDuration, 'value': '40'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        if (oldVersion < 5) {
          // Add price and service_description columns to appointments table
          await db.execute('ALTER TABLE appointments ADD COLUMN price REAL');
          await db.execute('ALTER TABLE appointments ADD COLUMN service_description TEXT');

          // Backfill existing appointments with current default values
          final settingsResult = await db.query('settings');
          final settings = {
            for (final row in settingsResult)
              row['key'] as String: row['value'] as String? ?? ''
          };
          final defaultPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '40.0') ?? 40.0;
          final defaultServiceDesc = settings[SettingsKeys.serviceDescription] ?? 'Chiropractic adjustment';

          await db.update(
            'appointments',
            {'price': defaultPrice, 'service_description': defaultServiceDesc},
          );
        }
      },
      version: 5,
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /// Close and reset database instance (for restore operations)
  Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Get the database file path
  Future<String> getDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'chiropractic_app.db');
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

  /// Delete a receipt (receipt_items cascade delete automatically)
  Future<void> deleteReceipt(int receiptId) async {
    final db = await database;
    await db.delete('receipts', where: 'id = ?', whereArgs: [receiptId]);
  }

  ///  Recurring: create a series + its appointments
  Future<void> createSeriesAndAppointments({ required Series series }) async {
    final db = await database;
    // Get default settings
    final settings = await getAllSettings();
    final durationMinutes = int.tryParse(settings[SettingsKeys.defaultAppointmentDuration] ?? '40') ?? 40;
    final defaultPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '40.0') ?? 40.0;
    final defaultServiceDesc = settings[SettingsKeys.serviceDescription] ?? 'Chiropractic adjustment';

    await db.transaction((txn) async {
      final sid = await txn.insert('series', series.toMap());
      DateTime dt = series.startDateTime;
      final limit = series.endDate ?? dt.add(const Duration(days:365*5));
      final delta = series.frequency == 'BIWEEKLY'
        ? const Duration(days:14)
        : const Duration(days:7);
      while (!dt.isAfter(limit)) {
        final endDt = dt.add(Duration(minutes: durationMinutes));
        await txn.insert('appointments', {
          'patient_id': series.patientId,
          'datetime': dt.toIso8601String(),
          'end_datetime': endDt.toIso8601String(),
          'notes': '',
          'paid': 0,
          'series_id': sid,
          'price': defaultPrice,
          'service_description': defaultServiceDesc,
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

  /* SETTINGS */

  /// Get a single setting value by key
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  /// Set a single setting value
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all settings as a map
  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final result = await db.query('settings');
    return {
      for (final row in result)
        row['key'] as String: row['value'] as String? ?? ''
    };
  }

  /// Save multiple settings at once
  Future<void> saveAllSettings(Map<String, String> settings) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in settings.entries) {
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /* METRICS QUERIES */

  /// Get all appointments within a date range
  Future<List<Appointment>> getAppointmentsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'appointments',
      where: 'datetime >= ? AND datetime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'datetime DESC',
    );
    return maps.map((row) => Appointment.fromMap(row)).toList();
  }

  /// Get count of distinct patients with appointments in range
  Future<int> getActivePatientsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT patient_id) as count FROM appointments WHERE datetime >= ? AND datetime < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Get count of patients whose first appointment is within range (new patients)
  Future<int> getNewPatientsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM (
        SELECT patient_id, MIN(datetime) as first_appt
        FROM appointments
        GROUP BY patient_id
        HAVING first_appt >= ? AND first_appt < ?
      )
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Get total patient count
  Future<int> getTotalPatientCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM patients');
    return result.first['count'] as int? ?? 0;
  }

  /// Get count of active series (no end date or end date in future)
  Future<int> getActiveSeriesCount() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM series WHERE end_date IS NULL OR end_date > ?',
      [now],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Get patients whose birthday is today (matching month and day)
  Future<List<Patient>> getPatientsWithBirthdayToday() async {
    final db = await database;
    final now = DateTime.now();
    final monthDay = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // DOB is stored as 'YYYY-MM-DD', so we check if it ends with the current month-day
    final result = await db.rawQuery(
      "SELECT * FROM patients WHERE substr(dob, 6) = ?",
      [monthDay],
    );
    return result.map((row) => Patient(
      id: row['id'] as int?,
      firstName: row['first_name'] as String? ?? '',
      middleName: row['middle_name'] as String?,
      lastName: row['last_name'] as String? ?? '',
      gender: row['gender'] as String?,
      dob: row['dob'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      address: row['address'] as String?,
    )).toList();
  }

  /// Get patients whose birthday was in the past week (including today)
  /// Returns list of (Patient, daysAgo) where daysAgo is 0 for today, 1 for yesterday, etc.
  Future<List<(Patient, int)>> getPatientsWithBirthdayInPastWeek() async {
    final db = await database;
    final now = DateTime.now();
    final results = <(Patient, int)>[];

    // Check each day from today back 6 days (7 days total including today)
    for (int daysAgo = 0; daysAgo <= 6; daysAgo++) {
      final date = now.subtract(Duration(days: daysAgo));
      final monthDay = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final rows = await db.rawQuery(
        "SELECT * FROM patients WHERE substr(dob, 6) = ?",
        [monthDay],
      );

      for (final row in rows) {
        final patient = Patient(
          id: row['id'] as int?,
          firstName: row['first_name'] as String? ?? '',
          middleName: row['middle_name'] as String?,
          lastName: row['last_name'] as String? ?? '',
          gender: row['gender'] as String?,
          dob: row['dob'] as String?,
          email: row['email'] as String?,
          phone: row['phone'] as String?,
          address: row['address'] as String?,
        );
        results.add((patient, daysAgo));
      }
    }

    return results;
  }

  /// Get patients whose birthday is in the next week (not including today)
  /// Returns list of (Patient, daysUntil) where daysUntil is 1 for tomorrow, 2 for day after, etc.
  Future<List<(Patient, int)>> getPatientsWithBirthdayInNextWeek() async {
    final db = await database;
    final now = DateTime.now();
    final results = <(Patient, int)>[];

    // Check each day from tomorrow to 7 days from now
    for (int daysUntil = 1; daysUntil <= 7; daysUntil++) {
      final date = now.add(Duration(days: daysUntil));
      final monthDay = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final rows = await db.rawQuery(
        "SELECT * FROM patients WHERE substr(dob, 6) = ?",
        [monthDay],
      );

      for (final row in rows) {
        final patient = Patient(
          id: row['id'] as int?,
          firstName: row['first_name'] as String? ?? '',
          middleName: row['middle_name'] as String?,
          lastName: row['last_name'] as String? ?? '',
          gender: row['gender'] as String?,
          dob: row['dob'] as String?,
          email: row['email'] as String?,
          phone: row['phone'] as String?,
          address: row['address'] as String?,
        );
        results.add((patient, daysUntil));
      }
    }

    return results;
  }

  /// Get oldest unpaid appointments (past appointments only) with patient info
  /// Returns up to [limit] appointments, sorted by date ascending (oldest first)
  Future<List<Map<String, dynamic>>> getOldestUnpaidAppointments({int limit = 100}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT
        a.id as appointment_id,
        a.datetime,
        a.notes,
        p.id as patient_id,
        p.first_name,
        p.last_name,
        p.phone
      FROM appointments a
      JOIN patients p ON a.patient_id = p.id
      WHERE a.paid = 0 AND a.datetime < ?
      ORDER BY a.datetime ASC
      LIMIT ?
    ''', [now, limit]);
    return result;
  }
}

