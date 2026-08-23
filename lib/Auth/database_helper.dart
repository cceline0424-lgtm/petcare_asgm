import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'pet_health_care.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        phone TEXT NOT NULL UNIQUE, 
        password TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertUser({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final db = await instance.database;
    return await db.insert(
      'users',
      {
        'name': name,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await instance.database;
    final results = await db.query('users', where: 'username = ?', whereArgs: [username], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await instance.database;
    final results = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final db = await instance.database;
    final results = await db.query('users', where: 'phone = ?', whereArgs: [phone], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> isUsernameTaken(String username) async {
    return await getUserByUsername(username) != null;
  }

  Future<bool> isEmailTaken(String email) async {
    return await getUserByEmail(email) != null;
  }

  Future<bool> isPhoneTaken(String phone) async {
    return await getUserByPhone(phone) != null;
  }

  Future<Map<String, dynamic>?> validateLogin(String username, String password) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: '(username = ? OR email = ?) AND password = ?',
      whereArgs: [username, username, password],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updatePasswordByEmail(String email, String newPassword) async {
    final db = await instance.database;
    return await db.update('users', {'password': newPassword}, where: 'email = ?', whereArgs: [email]);
  }
}