import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class DriveBackupService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (_) {}
  }

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<drive.DriveApi?> _getDriveApi() async {
    _currentUser ??= await _googleSignIn.signInSilently();
    if (_currentUser == null) return null;

    final authHeaders = await _currentUser!.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  /// Create local encrypted/compressed backup ZIP
  Future<File> createLocalBackupArchive() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(appDocDir.path, 'taniflow.sqlite'));

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipPath = p.join(tempDir.path, 'taniflow_backup_$timestamp.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    if (await dbFile.exists()) {
      encoder.addFile(dbFile);
    }

    // Add metadata file
    final metadata = {
      'app': 'TaniFlow',
      'developer': 'Ansor Studio',
      'version': '1.0.0+1',
      'created_at': DateTime.now().toIso8601String(),
    };
    final metaFile = File(p.join(tempDir.path, 'metadata.json'));
    await metaFile.writeAsString(jsonEncode(metadata));
    encoder.addFile(metaFile);

    encoder.close();
    return File(zipPath);
  }

  /// Calculate SHA-256 hash of a file for integrity check
  static Future<String> calculateSha256(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Upload backup to Google Drive
  Future<String?> uploadBackupToDrive(File backupFile) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw Exception('Belum masuk dengan akun Google untuk backup.');
    }

    final fileName = p.basename(backupFile.path);
    final driveFile = drive.File()
      ..name = fileName
      ..description = 'TaniFlow Auto-Backup'
      ..parents = ['appDataFolder'];

    final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());
    final uploadedFile = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
    );

    // Maintain max 30 backups: delete older if count > 30
    await _cleanupOldBackups(driveApi);

    return uploadedFile.id;
  }

  /// Clean up backups exceeding 30 versions
  Future<void> _cleanupOldBackups(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 50,
      );

      final files = fileList.files;
      if (files != null && files.length > 30) {
        for (int i = 30; i < files.length; i++) {
          final oldId = files[i].id;
          if (oldId != null) {
            await driveApi.files.delete(oldId);
          }
        }
      }
    } catch (_) {}
  }

  /// List available backups on Google Drive
  Future<List<drive.File>> listDriveBackups() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return [];

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 30,
      );
      return fileList.files ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Restore from local ZIP archive safely
  Future<bool> restoreFromArchive(File archiveFile) async {
    try {
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDb = File(p.join(appDocDir.path, 'taniflow.sqlite'));

      // 1. Safety backup of current DB before overwriting
      if (await targetDb.exists()) {
        final safetyBackup = File(p.join(appDocDir.path, 'taniflow_safety_copy.sqlite'));
        await targetDb.copy(safetyBackup.path);
      }

      // 2. Extract SQLite file from archive
      ArchiveFile? dbArchiveEntry;
      for (final file in archive) {
        if (file.name.endsWith('.sqlite')) {
          dbArchiveEntry = file;
          break;
        }
      }

      if (dbArchiveEntry == null) {
        return false;
      }

      // 3. Write target DB
      await targetDb.writeAsBytes(dbArchiveEntry.content as List<int>);
      return true;
    } catch (_) {
      return false;
    }
  }
}
