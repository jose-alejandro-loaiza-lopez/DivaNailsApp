import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
      onOpen: _onOpenDB,
    );
  }

  Future<void> _onOpenDB(Database db) async {
    // FK intentionally left OFF — app handles referential integrity in code
    await db.execute('PRAGMA foreign_keys = OFF');
    await _repairClientsTable(db);
    await _migrateClientsSchema(db);
  }

  Future<void> _repairClientsTable(Database db) async {
    await db.execute('DROP TABLE IF EXISTS clients_old');
    try {
      await db.query('clients', limit: 1);
    } catch (_) {
      await db.execute('''
        CREATE TABLE clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone TEXT NOT NULL DEFAULT '',
          name TEXT NOT NULL,
          last_name TEXT DEFAULT '',
          birth_day INTEGER,
          birth_month INTEGER,
          location TEXT DEFAULT ''
        )
      ''');
    }
  }

  Future<void> _migrateClientsSchema(Database db) async {
    List<Map<String, dynamic>> info;
    try {
      info = await db.rawQuery('PRAGMA table_info(clients)');
    } catch (_) {
      return;
    }
    final infoList = info.cast<Map<String, dynamic>>();
    final phoneCol = infoList.firstWhere(
      (c) => c['name'] == 'phone',
      orElse: () => <String, dynamic>{'notnull': 0},
    );
    final hasLastName = infoList.any((c) => c['name'] == 'last_name');
    if (phoneCol['notnull'] == 1 || !hasLastName) {
      await db.execute('''
        CREATE TABLE clients_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone TEXT NOT NULL DEFAULT '',
          name TEXT NOT NULL,
          last_name TEXT DEFAULT '',
          birth_day INTEGER,
          birth_month INTEGER,
          location TEXT DEFAULT ''
        )
      ''');
      await db.execute('INSERT INTO clients_new SELECT * FROM clients');
      if (!hasLastName) {
        await db.execute('UPDATE clients_new SET last_name = \'\' WHERE last_name IS NULL');
      }
      await db.execute('UPDATE clients_new SET phone = \'\' WHERE phone IS NULL');
      await db.execute('DROP TABLE clients');
      await db.execute('ALTER TABLE clients_new RENAME TO clients');
    }
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_appointments_client ON appointments(client_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_appointments_manicurist ON appointments(manicurist_id)');
    }
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
        client_id INTEGER,
        client_phone TEXT DEFAULT '',
        service_ids TEXT NOT NULL,
        manicurist_id INTEGER,
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
        phone TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        last_name TEXT DEFAULT '',
        birth_day INTEGER,
        birth_month INTEGER,
        location TEXT DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_appointments_date ON appointments(date)');
    await db.execute('CREATE INDEX idx_appointments_client ON appointments(client_id)');
    await db.execute('CREATE INDEX idx_appointments_manicurist ON appointments(manicurist_id)');
  }

  Future<int> insertService(Service service) async {
    final db = await database;
    return await db.insert('services', service.toMap());
  }

  Future<int> updateService(Service service) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await txn.update(
        'services',
        service.toMap(),
        where: 'id = ?',
        whereArgs: [service.id],
      );
      final rows = await txn.query('appointments',
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
          await txn.update('appointments',
              {'service_ids': jsonEncode(raw)},
              where: 'id = ?',
              whereArgs: [row['id']]);
        }
      }
      return id;
    });
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
    return await db.transaction((txn) async {
      final id = await txn.update(
        'manicurists',
        manicurist.toMap(),
        where: 'id = ?',
        whereArgs: [manicurist.id],
      );
      await txn.update(
        'appointments',
        {'manicurist_name': manicurist.name},
        where: 'manicurist_id = ?',
        whereArgs: [manicurist.id],
      );
      return id;
    });
  }

  Future<int> deleteManicurist(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final man = await txn.query('manicurists', where: 'id = ?', whereArgs: [id]);
      if (man.isNotEmpty) {
        await txn.update('appointments',
            {
              'manicurist_name': man.first['name'],
              'manicurist_id': null,
            },
            where: 'manicurist_id = ?',
            whereArgs: [id]);
      } else {
        await txn.update('appointments',
            {'manicurist_id': null},
            where: 'manicurist_id = ?',
            whereArgs: [id]);
      }
      return await txn.delete('manicurists', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Manicurist>> getManicurists() async {
    final db = await database;
    final maps = await db.query('manicurists', orderBy: 'id ASC');
    return maps.map((map) => Manicurist.fromMap(map)).toList();
  }

  Future<int> insertClient(Client client) async {
    final db = await database;
    return await db.insert('clients', client.toMap());
  }

  Future<int> updateClient(Client client) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await txn.update(
        'clients',
        client.toMap(),
        where: 'id = ?',
        whereArgs: [client.id],
      );
      await txn.update(
        'appointments',
        {
          'client_name': client.fullName,
          'client_phone': client.phone,
        },
        where: 'client_id = ?',
        whereArgs: [client.id],
      );
      return id;
    });
  }

  Future<int> deleteClient(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final client = await txn.query('clients', where: 'id = ?', whereArgs: [id]);
      if (client.isNotEmpty) {
        final cName = (client.first['name'] as String?) ?? '';
        final cLastName = (client.first['last_name'] as String?) ?? '';
        final cFullName = cLastName.isNotEmpty ? '$cName $cLastName' : cName;
        await txn.update('appointments',
            {
              'client_name': cFullName,
              'client_phone': client.first['phone'],
              'client_id': null,
            },
            where: 'client_id = ?',
            whereArgs: [id]);
      } else {
        await txn.update('appointments',
            {'client_id': null},
            where: 'client_id = ?',
            whereArgs: [id]);
      }
      return await txn.delete('clients', where: 'id = ?', whereArgs: [id]);
    });
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

  Future<Map<int, int>> getAppointmentCountsGroupedByClient() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT client_id, COUNT(*) as cnt FROM appointments WHERE client_id IS NOT NULL GROUP BY client_id',
    );
    final map = <int, int>{};
    for (final row in result) {
      map[row['client_id'] as int] = row['cnt'] as int;
    }
    return map;
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
    } catch (e) {
      debugPrint('Error en backupIfNewDay: $e');
    }
  }
}
