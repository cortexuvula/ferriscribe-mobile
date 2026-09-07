import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_logger.dart';
import '../../pairing/server_config_repository.dart';
import 'models.dart';

/// A processing job's current state, as served by the server's in-memory
/// job registry (`GET /v1/jobs/{id}`).
class JobSnapshot {
  const JobSnapshot({
    required this.recordingId,
    required this.stage,
    required this.updatedAt,
    this.error,
  });

  final String recordingId;
  final String stage;
  final String? error;
  final String updatedAt;

  factory JobSnapshot.fromJson(Map<String, dynamic> json) {
    return JobSnapshot(
      recordingId: json['recording_id'] as String? ?? '',
      stage: json['stage'] as String? ?? 'unknown',
      updatedAt: json['updated_at'] as String? ?? '',
      error: json['error'] as String?,
    );
  }

  bool get isTerminal => stage == 'completed' || stage == 'failed';
}

/// A freshly created recording row (`POST /v1/recordings`).
class CreatedRecording {
  const CreatedRecording({required this.id, required this.createdAt});

  final String id;
  final String createdAt;
}

/// Thrown for any non-2xx/3xx data-API response. [statusCode] is the HTTP
/// status; [message] is non-PHI context (no transcript/audio/patient data).
class DataApiException implements Exception {
  const DataApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'DataApiException($statusCode): $message';
}

/// Thin client for the :11437 data API (verified against
/// `src-tauri/src/sharing_vocab_api/mobile.rs` + `audio.rs`).
///
/// Auth is `Authorization: Bearer <token>` on every request (long-lived token,
/// no refresh). All payloads are IDs/counts/lengths — never PHI in logs.
class DataApiClient {
  DataApiClient({
    required String host,
    required int port,
    required this.token,
    http.Client? client,
  }) : baseUrl = _baseUrl(host, port),
       _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  static String _baseUrl(String host, int port) {
    final h = (host.contains(':') && !host.startsWith('[')) ? '[$host]' : host;
    return 'http://$h:$port';
  }

  factory DataApiClient.forConfig(ServerConfig config, String token) =>
      DataApiClient(host: config.host, port: config.dataPort, token: token);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  /// `POST /v1/recordings` — create a recording row (audio arrives via
  /// [uploadAudio]).
  Future<CreatedRecording> createRecording({
    required String id,
    required String filename,
    double? durationSeconds,
  }) async {
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/v1/recordings'),
          headers: _headers,
          // `?durationSeconds` is Dart's null-aware map entry: the key is
          // omitted entirely when null (server treats the field as optional).
          body: jsonEncode({
            'id': id,
            'filename': filename,
            'duration_seconds': ?durationSeconds,
          }),
        )
        .timeout(const Duration(seconds: 15));
    AppLog.status('recordings.create', resp.statusCode);
    if (resp.statusCode != 201) {
      throw DataApiException(resp.statusCode, 'create recording failed');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return CreatedRecording(
      id: body['id'] as String? ?? id,
      createdAt: body['created_at'] as String? ?? '',
    );
  }

  /// `PUT /v1/content/audio/{id}` — upload plaintext WAV bytes. The server
  /// encrypts at rest on receipt. First-write-wins (409 if already present).
  ///
  /// The body is the WAV held in memory — no temp file is written on this
  /// side. Returns the uploaded byte count.
  Future<int> uploadAudio(String recordingId, List<int> wavBytes) async {
    AppLog.byteLength('audio.upload', wavBytes.length);
    final resp = await _client
        .put(
          Uri.parse('$baseUrl/v1/content/audio/$recordingId'),
          headers: {'Authorization': 'Bearer $token'},
          body: wavBytes,
        )
        .timeout(const Duration(minutes: 5));
    AppLog.status('audio.upload', resp.statusCode);
    if (resp.statusCode != 201) {
      throw DataApiException(resp.statusCode, 'audio upload failed');
    }
    return wavBytes.length;
  }

  /// `POST /v1/recordings/{id}/generate/soap` — queue the transcribe→SOAP
  /// pipeline. 202 accepted; progress via [jobStatus]/[jobEvents].
  Future<void> generateSoap(String recordingId) async {
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/v1/recordings/$recordingId/generate/soap'),
          headers: _headers,
          body: '{}',
        )
        .timeout(const Duration(seconds: 15));
    AppLog.status('generate.soap', resp.statusCode);
    if (resp.statusCode != 202) {
      throw DataApiException(resp.statusCode, 'generate soap failed');
    }
  }

  /// `GET /v1/jobs/{id}` — current job snapshot, or null on 404 (unknown job).
  Future<JobSnapshot?> jobStatus(String recordingId) async {
    final resp = await _client
        .get(
          Uri.parse('$baseUrl/v1/jobs/$recordingId'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    AppLog.status('jobs.status', resp.statusCode);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw DataApiException(resp.statusCode, 'job status failed');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return JobSnapshot.fromJson(body);
  }

  /// `GET /v1/jobs/{id}/events` — SSE stream of stage changes.
  ///
  /// The server's initial event carries the current snapshot (or an
  /// `unknown` stage), then each stage change follows. Payloads are
  /// `{recording_id, stage, updated_at}` only — no PHI, no error text.
  Stream<JobSnapshot> jobEvents(String recordingId) async* {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/v1/jobs/$recordingId/events'),
    )..headers['Authorization'] = 'Bearer $token';

    final resp = await _client.send(request);
    AppLog.status('jobs.events', resp.statusCode);
    if (resp.statusCode != 200) {
      throw DataApiException(resp.statusCode, 'job events failed');
    }
    await for (final json in SseParser.parseJson(resp.stream)) {
      yield JobSnapshot.fromJson(json);
    }
  }

  void close() => _client.close();

  // ── Phase 2: content sync + documents ───────────────────────────────

  /// `GET /v1/content/sync` — incremental delta pull.
  ///
  /// [since] is an RFC 3339 watermark (omit for the initial full pull).
  /// Returns the page of recordings plus `has_more` for pagination.
  Future<ContentPullPage> pullContent({String? since, int? limit}) async {
    final uri = Uri.parse(
      '$baseUrl/v1/content/sync',
    ).replace(queryParameters: {'since': ?since, 'limit': ?limit?.toString()});
    final resp = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));
    AppLog.status('content.sync.pull', resp.statusCode);
    if (resp.statusCode != 200) {
      throw DataApiException(resp.statusCode, 'content sync pull failed');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final recordings = (body['recordings'] as List<dynamic>? ?? const [])
        .map((r) => SyncRecording.fromJson(r as Map<String, dynamic>))
        .toList();
    AppLog.count('content.sync.recordings', recordings.length);
    return ContentPullPage(
      recordings: recordings,
      serverTime: body['server_time'] as String? ?? '',
      hasMore: body['has_more'] as bool? ?? false,
    );
  }

  /// `GET /v1/recordings/{id}/documents/{doc_type}` — fetch one document.
  /// `content` is null when the document has not been generated yet.
  Future<RecordingDocument> getDocument(String recordingId, DocType doc) async {
    final resp = await _client
        .get(
          Uri.parse(
            '$baseUrl/v1/recordings/$recordingId/documents/${doc.wire}',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    AppLog.status('document.get', resp.statusCode);
    if (resp.statusCode != 200) {
      throw DataApiException(resp.statusCode, 'get document failed');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return RecordingDocument.fromJson(doc, body);
  }

  /// `PUT /v1/recordings/{id}/documents/{doc_type}` — save an edited document
  /// (204 on success).
  Future<void> saveDocument(
    String recordingId,
    DocType doc,
    String content,
  ) async {
    AppLog.count('document.put.chars', content.length);
    final resp = await _client
        .put(
          Uri.parse(
            '$baseUrl/v1/recordings/$recordingId/documents/${doc.wire}',
          ),
          headers: _headers,
          body: jsonEncode({'content': content}),
        )
        .timeout(const Duration(seconds: 30));
    AppLog.status('document.put', resp.statusCode);
    if (resp.statusCode != 204) {
      throw DataApiException(resp.statusCode, 'save document failed');
    }
  }

  /// `POST /v1/recordings/{id}/generate/{doc_type}` — queue generation (202).
  Future<void> generateDoc(
    String recordingId,
    DocType doc,
    GenerateRequest request,
  ) async {
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/v1/recordings/$recordingId/generate/${doc.wire}'),
          headers: _headers,
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    AppLog.status('generate.${doc.wire}', resp.statusCode);
    if (resp.statusCode != 202) {
      throw DataApiException(resp.statusCode, 'generate ${doc.wire} failed');
    }
  }
}

/// A page of content-sync pull results.
class ContentPullPage {
  const ContentPullPage({
    required this.recordings,
    required this.serverTime,
    required this.hasMore,
  });

  final List<SyncRecording> recordings;
  final String serverTime;
  final bool hasMore;
}

/// Minimal SSE parser: the server emits `data: {json}\n\n` frames (axum
/// `Event::default().data(...)`). Splits on blank-line boundaries and parses
/// each `data:` payload as JSON. No PHI is ever present in these frames.
class SseParser {
  SseParser._();

  /// Converts a raw byte stream (from `StreamedResponse.stream`) into parsed
  /// JSON event maps.
  static Stream<Map<String, dynamic>> parseJson(Stream<List<int>> bytes) {
    return bytes
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .transform(
          StreamTransformer<String, Map<String, dynamic>>.fromBind(
            _splitEvents,
          ),
        );
  }

  /// Accumulates SSE `data:` lines and emits one parsed JSON map per
  /// blank-line (event) boundary.
  static Stream<Map<String, dynamic>> _splitEvents(
    Stream<String> stream,
  ) async* {
    final data = <String>[];
    await for (var line in stream) {
      // axum emits LF only, but strip a trailing CR defensively so the parser
      // also tolerates CRLF SSE sources.
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final payload = data.join('\n');
          data.clear();
          yield jsonDecode(payload) as Map<String, dynamic>;
        }
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
      // ignore `event:`, `id:`, `retry:`, and comment lines
    }
  }
}
