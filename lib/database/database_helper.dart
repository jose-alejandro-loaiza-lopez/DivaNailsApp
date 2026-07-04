import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service.dart';
import '../models/appointment.dart';
import '../models/manicurist.dart';
import '../models/client.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String _currentPath = '';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diva_nails.db');
    return _database!;
  }

  /// Returns the actual full path of the database file.
  static String get currentPath => _currentPath;

  static Future<String> _resolvePath(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final customDir = prefs.getString('customDbDir') ?? '';
    if (customDir.isNotEmpty) {
      final dir = Directory(customDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      return p.join(customDir, fileName);
    }
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, fileName);
  }

  Future<Database> _initDB(String filePath) async {
    final path = await _resolvePath(filePath);
    _currentPath = path;
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createDB,
    );
  }

  /// Save a custom DB directory. Pass an empty string to reset to default.
  /// If the target already has a DB file, it will be used as-is (no overwrite).
  /// Otherwise the current DB is copied there.
  /// The app must be restarted for the change to take effect.
  static Future<void> prepareMigration(String newDir) async {
    final prefs = await SharedPreferences.getInstance();

    if (newDir.isEmpty) {
      await prefs.remove('customDbDir');
      return;
    }

    final newPath = p.join(newDir, 'diva_nails.db');
    final dir = Directory(newDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    if (!await File(newPath).exists()) {
      final oldPath = _currentPath;
      if (await File(oldPath).exists()) {
        await File(oldPath).copy(newPath);
      }
    }

    await prefs.setString('customDbDir', newDir);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_name TEXT DEFAULT '',
        client_id INTEGER REFERENCES clients(id),
        client_phone TEXT DEFAULT '',
        service_ids TEXT NOT NULL,
        manicurist_id INTEGER REFERENCES manicurists(id),
        manicurist_name TEXT DEFAULT '',
        date TEXT NOT NULL,
        total_price REAL NOT NULL,
        payment_data TEXT DEFAULT '[]',
        time TEXT DEFAULT '',
        adicional REAL DEFAULT 0.0,
        descripcion TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE manicurists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        profit_percentage REAL DEFAULT 40.0
      )
    ''');
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        birth_day INTEGER,
        birth_month INTEGER,
        location TEXT DEFAULT ''
      )
    ''');
  }

  Future<int> insertService(Service service) async {
    final db = await database;
    return await db.insert('services', service.toMap());
  }

  Future<int> updateService(Service service) async {
    final db = await database;
    final id = await db.update(
      'services',
      service.toMap(),
      where: 'id = ?',
      whereArgs: [service.id],
    );
    final rows = await db.query('appointments',
        columns: ['id', 'service_ids']);
    for (final row in rows) {
      final raw = jsonDecode(row['service_ids'] as String) as List;
      bool changed = false;
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] is Map && raw[i]['service_id'] == service.id) {
          raw[i]['name'] = service.name;
          changed = true;
        }
      }
      if (changed) {
        await db.update('appointments',
            {'service_ids': jsonEncode(raw)},
            where: 'id = ?',
            whereArgs: [row['id']]);
      }
    }
    return id;
  }

  Future<int> deleteService(int id) async {
    final db = await database;
    return await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Service>> getServices() async {
    final db = await database;
    final maps = await db.query('services', orderBy: 'id ASC');
    return maps.map((map) => Service.fromMap(map)).toList();
  }

  Future<int> insertAppointment(Appointment appointment) async {
    final db = await database;
    return await db.insert('appointments', appointment.toMap());
  }

  Future<int> updateAppointment(Appointment appointment) async {
    final db = await database;
    return await db.update(
      'appointments',
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
  }

  Future<int> deleteAppointment(int id) async {
    final db = await database;
    return await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    final db = await database;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'appointments',
      where: 'date = ?',
      whereArgs: [dateStr],
      orderBy: "(time = '' OR time IS NULL) ASC, time ASC, id ASC",
    );
    return maps.map((map) => Appointment.fromMap(map)).toList();
  }

  Future<List<Appointment>> getAppointmentsInRange(DateTime from, DateTime to) async {
    final db = await database;
    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr =
        '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'appointments',
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromStr, toStr],
      orderBy: 'date ASC, time ASC, id ASC',
    );
    return maps.map((map) => Appointment.fromMap(map)).toList();
  }

  Future<int> insertManicurist(Manicurist manicurist) async {
    final db = await database;
    return await db.insert('manicurists', manicurist.toMap());
  }

  Future<int> updateManicurist(Manicurist manicurist) async {
    final db = await database;
    final id = await db.update(
      'manicurists',
      manicurist.toMap(),
      where: 'id = ?',
      whereArgs: [manicurist.id],
    );
    await db.update(
      'appointments',
      {'manicurist_name': manicurist.name},
      where: 'manicurist_id = ?',
      whereArgs: [manicurist.id],
    );
    return id;
  }

  Future<int> deleteManicurist(int id) async {
    final db = await database;
    final man = await db.query('manicurists', where: 'id = ?', whereArgs: [id]);
    if (man.isNotEmpty) {
      await db.update('appointments',
          {
            'manicurist_name': man.first['name'],
            'manicurist_id': null,
          },
          where: 'manicurist_id = ?',
          whereArgs: [id]);
    } else {
      await db.update('appointments',
          {'manicurist_id': null},
          where: 'manicurist_id = ?',
          whereArgs: [id]);
    }
    return await db.delete('manicurists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Manicurist>> getManicurists() async {
    final db = await database;
    final maps = await db.query('manicurists', orderBy: 'id ASC');
    return maps.map((map) => Manicurist.fromMap(map)).toList();
  }

  Future<int> insertClient(Client client) async {
    final db = await database;
    try {
      return await db.insert('clients', client.toMap());
    } catch (_) {
      await db.update(
        'clients',
        client.toMap(),
        where: 'phone = ?',
        whereArgs: [client.phone],
      );
      final rows = await db.query('clients', where: 'phone = ?', whereArgs: [client.phone]);
      return rows.first['id'] as int;
    }
  }

  Future<int> updateClient(Client client) async {
    final db = await database;
    final id = await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
    await db.update(
      'appointments',
      {
        'client_name': '${client.name} ${client.lastName}',
        'client_phone': client.phone,
      },
      where: 'client_id = ?',
      whereArgs: [client.id],
    );
    return id;
  }

  Future<int> deleteClient(int id) async {
    final db = await database;
    final client = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (client.isNotEmpty) {
      await db.update('appointments',
          {
            'client_name': '${client.first['name']} ${client.first['last_name']}',
            'client_phone': client.first['phone'],
            'client_id': null,
          },
          where: 'client_id = ?',
          whereArgs: [id]);
    } else {
      await db.update('appointments',
          {'client_id': null},
          where: 'client_id = ?',
          whereArgs: [id]);
    }
    return await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Client>> getClients() async {
    final db = await database;
    final maps = await db.query('clients', orderBy: 'name ASC, last_name ASC');
    return maps.map((map) => Client.fromMap(map)).toList();
  }

  Future<Client?> getClientByPhone(String phone) async {
    final db = await database;
    final maps = await db.query('clients', where: 'phone = ?', whereArgs: [phone]);
    if (maps.isEmpty) return null;
    return Client.fromMap(maps.first);
  }

  Future<int> getAppointmentsCountByClient(int clientId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM appointments WHERE client_id = ?',
      [clientId],
    );
    return result.first['cnt'] as int;
  }

  Future<List<Appointment>> getAppointmentsByClient(int clientId) async {
    final db = await database;
    final maps = await db.query(
      'appointments',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'date DESC, time DESC',
    );
    return maps.map((map) => Appointment.fromMap(map)).toList();
  }

  static const _dayNames = {
    1: 'lunes',
    2: 'martes',
    3: 'miercoles',
    4: 'jueves',
    5: 'viernes',
    6: 'sabado',
    7: 'domingo',
  };

  Future<void> backupIfNewDay() async {
    try {
      final dbPath = _currentPath;
      final dbDir = Directory(p.dirname(dbPath));
      final backupDir = Directory(p.join(dbDir.path, 'Backups'));
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final today = DateTime.now();
      final dayOfWeek = today.weekday;
      final dayName = _dayNames[dayOfWeek] ?? 'dia_$dayOfWeek';
      final backupPath = p.join(backupDir.path, 'diva_nails_$dayName.db');

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        final stat = await backupFile.stat();
        final lastModified = stat.modified;
        final diff = today.difference(lastModified);
        if (diff.inHours < 24) return;
      }

      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
      }
    } catch (_) {
      // Silently fail — backup is best-effort
    }
  }
}
