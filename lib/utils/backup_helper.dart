import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'database_helper.dart';

class BackupHelper {
  static const int maxAutoBackups = 5;

  /// Auto-backup to app data folder (called on app close)
  static Future<void> autoBackup() async {
    try {
      // Get source database path
      final dbPath = await DatabaseHelper().getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) return;

      // Get backup directory
      final appDir = await getApplicationSupportDirectory();
      final backupDir = Directory(path.join(appDir.path, 'backups'));

      // Create backups folder if needed
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Rotate old backups first
      await _rotateBackups(backupDir);

      // Create new backup with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final backupPath = path.join(backupDir.path, 'auto_backup_$timestamp.db');

      await dbFile.copy(backupPath);

      // Update last backup date in settings
      await DatabaseHelper().setSetting(
        SettingsKeys.lastBackupDate,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Silent fail for auto-backup - don't block app close
      debugPrint('Auto-backup failed: $e');
    }
  }

  /// Rotate backups - delete oldest if over limit
  static Future<void> _rotateBackups(Directory backupDir) async {
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => path.basename(f.path).startsWith('auto_backup_'))
        .toList();

    // Sort by name (timestamp in filename = chronological order)
    files.sort((a, b) => a.path.compareTo(b.path));

    // Delete oldest files if at or over limit
    while (files.length >= maxAutoBackups) {
      await files.removeAt(0).delete();
    }
  }

  /// Export database to user-selected folder
  static Future<bool> exportBackup(BuildContext context) async {
    try {
      // Let user pick folder
      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save backup',
      );

      if (selectedDir == null) return false;

      // Get source database path
      final dbPath = await DatabaseHelper().getDatabasePath();
      final dbFile = File(dbPath);

      // Create backup with timestamp
      final timestamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final backupPath = path.join(selectedDir, 'chiropractic_backup_$timestamp.db');

      await dbFile.copy(backupPath);

      // Update last backup date
      await DatabaseHelper().setSetting(
        SettingsKeys.lastBackupDate,
        DateTime.now().toIso8601String(),
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to $backupPath')),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
      return false;
    }
  }

  /// Import database from user-selected file (with confirmation)
  static Future<bool> importBackup(BuildContext context) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Restore from Backup'),
          ],
        ),
        content: const Text(
          'This will REPLACE all current data with the backup.\n\n'
          'Any changes made since the backup will be lost.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      // Let user pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select backup file to restore',
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return false;
      }

      final backupPath = result.files.first.path!;

      // Verify it's a .db file
      if (!backupPath.endsWith('.db')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a .db backup file')),
          );
        }
        return false;
      }

      // Get destination database path
      final dbPath = await DatabaseHelper().getDatabasePath();

      // Close current database
      await DatabaseHelper().closeAndReset();

      // Copy backup file over current database
      final backupFile = File(backupPath);
      await backupFile.copy(dbPath);

      // Show success message with restart prompt
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data restored successfully. Please restart the app.'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
      return false;
    }
  }

  /// Get last backup date for display
  static Future<DateTime?> getLastBackupDate() async {
    final dateStr = await DatabaseHelper().getSetting(SettingsKeys.lastBackupDate);
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Format last backup date for display
  static Future<String> getLastBackupDisplayString() async {
    final date = await getLastBackupDate();
    if (date == null) return 'Never';
    return DateFormat.yMMMd().add_jm().format(date);
  }
}
