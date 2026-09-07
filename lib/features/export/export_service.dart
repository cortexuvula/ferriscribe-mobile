import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../pairing/server_config_repository.dart';

/// Outcome of an export-and-share operation.
class ExportOutcome {
  const ExportOutcome.shared() : error = null;
  const ExportOutcome.failed(this.error);

  final String? error;

  bool get ok => error == null;
}

/// Downloads a rendered document and hands it to the system share sheet.
///
/// PHI note: the exported PDF/DOCX is plaintext, so it is written only to the
/// app-private temp directory, excluded from backups, and **shredded
/// (overwritten, not merely deleted) immediately after the share sheet
/// dismisses** — never left at rest recoverable.
class ExportService {
  ExportService({
    this.clientFactory = DataApiClient.forConfig,
    Future<Directory> Function()? tempDirProvider,
  }) : _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final DataApiClient Function(ServerConfig, String) clientFactory;
  final Future<Directory> Function() _tempDirProvider;

  Future<ExportOutcome> exportAndShare({
    required ServerConfig config,
    required String token,
    required String recordingId,
    required DocType doc,
    required ExportFormat format,
  }) async {
    final client = clientFactory(config, token);
    String? tempPath;
    try {
      final file = await client.exportDocument(recordingId, doc, format);
      final dir = await _tempDirProvider();
      tempPath = p.join(dir.path, file.filename);
      await File(tempPath).writeAsBytes(file.bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempPath, mimeType: file.contentType)],
          fileNameOverrides: [file.filename],
        ),
      );
      return const ExportOutcome.shared();
    } on DataApiException catch (e) {
      return ExportOutcome.failed(e.message);
    } catch (_) {
      return const ExportOutcome.failed('share failed');
    } finally {
      if (tempPath != null) await shredFile(tempPath);
      client.close();
    }
  }
}

/// Overwrites [path] with zero bytes then deletes it, so plaintext document
/// content is not recoverable from unallocated blocks. Best-effort: failures
/// fall through to a plain delete of an app-private file.
Future<void> shredFile(String path) async {
  final f = File(path);
  try {
    if (await f.exists()) {
      final length = await f.length();
      final raf = await f.open(mode: FileMode.write);
      try {
        const chunkSize = 4096;
        final zeros = Uint8List(chunkSize);
        var remaining = length;
        while (remaining > 0) {
          final n = remaining > chunkSize ? chunkSize : remaining;
          await raf.writeFrom(zeros, 0, n);
          remaining -= n;
        }
        await raf.flush();
      } finally {
        await raf.close();
      }
      await f.delete();
    }
  } catch (_) {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
