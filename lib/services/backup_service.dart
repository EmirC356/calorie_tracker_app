import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'prefs.dart';

/// Exports/imports all on-device data as a single JSON file so a user can back
/// up and restore (e.g. onto a new phone). The Gemini API key is intentionally
/// NOT included. Restore is a full replace, run inside one transaction.
class BackupService {
  final DatabaseService _db;
  BackupService({DatabaseService? db}) : _db = db ?? DatabaseService();

  static const int backupVersion = 1;
  static const String appTag = 'calorie_tracker';

  /// All data tables, parents before children (matters for restore order).
  static const List<String> _tables = [
    DatabaseService.tablesGoals,
    DatabaseService.tablesGoalOccurrences,
    DatabaseService.tablesGoalSuggestions,
    DatabaseService.tablesMeals,
    DatabaseService.tablesExercises,
    DatabaseService.tablesMealPreps,
    DatabaseService.tablesWeightEntries,
  ];

  Future<Map<String, dynamic>> exportToMap() async {
    final database = await _db.db;
    final tables = <String, dynamic>{};
    for (final t in _tables) {
      tables[t] = await database.query(t);
    }
    final prefs = await SharedPreferences.getInstance();
    return {
      'app': appTag,
      'backupVersion': backupVersion,
      'schemaVersion': DatabaseService.currentSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': prefs.getString(kUserProfilePref),
      'tables': tables,
    };
  }

  Future<String> exportToJsonString() async =>
      const JsonEncoder.withIndent('  ').convert(await exportToMap());

  /// Writes the backup to a temp file and returns it (for the share sheet).
  Future<File> writeBackupFile() async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
    final file = File('${dir.path}/calorie_tracker_backup_$stamp.json');
    await file.writeAsString(await exportToJsonString());
    return file;
  }

  /// Restores from a backup map. Wipes the data tables and re-inserts every row
  /// (ids preserved so occurrence→goal references hold), then restores the
  /// profile. Throws [FormatException] if the file isn't one of our backups.
  Future<void> importFromMap(Map<String, dynamic> map) async {
    if (map['app'] != appTag || map['tables'] is! Map) {
      throw const FormatException('Not a Calorie Tracker backup file.');
    }
    final tablesData = (map['tables'] as Map).cast<String, dynamic>();
    final database = await _db.db;
    await database.transaction((txn) async {
      // Delete children before parents.
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
      // Insert parents before children.
      for (final t in _tables) {
        final rows = (tablesData[t] as List?) ?? const [];
        for (final row in rows) {
          await txn.insert(t, (row as Map).cast<String, dynamic>());
        }
      }
    });
    final profile = map['profile'] as String?;
    final prefs = await SharedPreferences.getInstance();
    if (profile != null) await prefs.setString(kUserProfilePref, profile);
  }

  Future<void> importFromJsonString(String json) async =>
      importFromMap(jsonDecode(json) as Map<String, dynamic>);

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
