import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppointmentStorage {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('petcare_appointments.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Define the table structure
  static Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        clinicName TEXT,
        date TEXT,
        time TEXT,
        service TEXT,
        petName TEXT,
        status TEXT
      )
    ''');
  }

  static Future<void> saveAppointment(Map<String, dynamic> appointmentData) async {
    final db = await database;

    appointmentData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    appointmentData['status'] = 'Upcoming';

    await db.insert('appointments', appointmentData);
  }

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    final db = await database;
    final result = await db.query('appointments');
    return result.map((map) => Map<String, dynamic>.from(map)).toList();
  }

  static Future<void> cancelAppointment(String id) async {
    final db = await database;
    await db.update(
      'appointments',
      {'status': 'Cancelled'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateAppointmentStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'appointments',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}