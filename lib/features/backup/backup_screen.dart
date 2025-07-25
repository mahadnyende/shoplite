import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/db.dart';
import '../../widgets/footer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupScreen extends StatefulWidget {
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? backupFolder;
  DateTime? lastBackup;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadBackupFolder();
    Future.delayed(Duration.zero, _autoBackupIfNeeded);
  }

  Future<void> _loadBackupFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      backupFolder = prefs.getString('backup_folder');
    });
  }

  Future<void> _saveBackupFolder(String folder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_folder', folder);
    setState(() {
      backupFolder = folder;
    });
  }

  Future<void> _autoBackupIfNeeded() async {
    if (backupFolder == null) return;
    if (lastBackup == null ||
        DateTime.now().difference(lastBackup!).inHours >= 4) {
      await _backup();
    }
  }

  Future<void> _backup() async {
    setState(() {
      loading = true;
    });
    final dbPath = await AppDatabase.database;
    final dbFile = File(dbPath.path);
    final backupDir = Directory(backupFolder!);
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

    // Count existing backups for backup number
    final existingBackups = backupDir
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.db') && f.path.contains('shoplite_backup_'),
        )
        .toList();
    final backupNumber = existingBackups.length + 1;
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH-mm-ss').format(now);
    String defaultName = 'shoplite_backup_${backupNumber}_${dateStr}|${timeStr}.db';

    // Allow user to edit only the file name, not the extension
    final fileName = p.basenameWithoutExtension(defaultName);
    final fileExt = p.extension(defaultName);
    final controller = TextEditingController(text: fileName);
    final editedBaseName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Backup File Name'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: 'Backup File Name'),
              ),
            ),
            SizedBox(width: 8),
            Text(fileExt, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text('Save'),
          ),
        ],
      ),
    );
    if (editedBaseName == null || editedBaseName.trim().isEmpty) {
      setState(() {
        loading = false;
      });
      return;
    }
    // Always enforce .db extension and sanitize file name
    String sanitizedBase = editedBaseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    if (!sanitizedBase.endsWith('.db')) {
      sanitizedBase += '.db';
    }
    final backupFile = File(p.join(backupFolder!, sanitizedBase));
    await dbFile.copy(backupFile.path);
    setState(() {
      lastBackup = DateTime.now();
      loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved to ${backupFile.path}')),
    );
  }

  Future<void> _restore() async {
    final dbPath = await AppDatabase.database;
    final dbFile = File(dbPath.path);
    // Use FilePicker for file selection
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      // Step 2: Confirm restore
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Restore'),
          content: Text(
            'Restoring will overwrite current data and refresh the app. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final backupFile = File(filePath);
        if (backupFile.existsSync()) {
          await dbFile.writeAsBytes(
            await backupFile.readAsBytes(),
            flush: true,
          );
          // Attempt to refresh app state after restore
          setState(() {
            lastBackup = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database restored and app refreshed.')),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Backup file not found.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backup & Restore', style: theme.textTheme.headlineSmall),
          SizedBox(height: 8),
          Text(
            'Secure your business data by creating regular backups. You can restore your data at any time using a previous backup file.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.folder, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Backup Folder:', style: theme.textTheme.titleMedium),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          backupFolder ?? 'Not selected',
                          style: TextStyle(fontWeight: FontWeight.w500, color: backupFolder == null ? Colors.red : Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(MdiIcons.folderSearch),
                        onPressed: () async {
                          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                          if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
                            await _saveBackupFolder(selectedDirectory);
                          }
                        },
                        label: Text('Select Folder'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.cloudUploadOutline),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text('Backup Now', style: TextStyle(fontSize: 16)),
                          ),
                          onPressed: backupFolder == null
                              ? null
                              : () async {
                                  await _backup();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(MdiIcons.restore),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text('Restore', style: TextStyle(fontSize: 16)),
                          ),
                          onPressed: _restore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(MdiIcons.clockOutline, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        lastBackup != null
                            ? 'Last backup: ${DateFormat('yyyy-MM-dd | HH:mm:ss').format(lastBackup!)}'
                            : 'No backup performed yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  if (loading) ...[
                    SizedBox(height: 16),
                    Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
          Spacer(),
          Footer(),
        ],
      ),
    );
  }
}
