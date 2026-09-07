import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/features/documents/document_editor_screen.dart';
import 'package:ferriscribe_mobile/features/documents/recordings_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';

/// Production-theme widget tests, requested in the visual re-review: the
/// screens must render real content under the PRODUCTION theme (both
/// brightnesses), driving the REAL network stack — not mocked widgets.
///
/// Constraint discovered while writing these: `TestWidgetsFlutterBinding`
/// intercepts every `HttpClient` and returns 400 (no real sockets inside
/// `testWidgets`), so the live-loopback-`HttpServer` pattern used by the
/// pure-async client tests cannot work here. Instead, these tests install
/// an `HttpOverrides` that answers with the *real server contract payloads*
/// (the exact JSON shapes served by `mobile.rs` / `content_sync.rs`), so the
/// entire client → JSON → adapter → widget pipeline runs for real; only the
/// socket itself is substituted.
void main() {
  Future<AppServices> makeServices() async {
    final db = AppDatabase(NativeDatabase.memory());
    final keys = MemoryKeyStore();
    final repo = ServerConfigRepository(db, keys);
    await repo.savePaired(
      label: 'phone',
      host: '127.0.0.1',
      pairingPort: 11436,
      dataPort: 11437,
      token: 't',
    );
    return AppServices(
      db: db,
      keyStore: keys,
      serverConfigRepository: repo,
      pairingService: PairingService(repository: repo),
      offlineCache: OfflineCacheRepository(db),
    );
  }

  ThemeData prodTheme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B6B93),
      brightness: b,
    ),
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('document editor renders a real successful document GET '
        '(${brightness.name})', (tester) async {
      final services = await makeServices();
      addTearDown(() => services.db.close());

      final overrides = _ContractOverrides((req) {
        if (req.uri.path.endsWith('/documents/soap')) {
          return _json(200, {
            'doc_type': 'soap',
            'content': 'S: real server content',
            'updated_at': '2026-09-07T12:00:00Z',
          });
        }
        return _json(404, {});
      });
      HttpOverrides.global = overrides;
      addTearDown(() => HttpOverrides.global = null);
      await tester.pumpWidget(
        MaterialApp(
          theme: prodTheme(brightness),
          home: DocumentEditorScreen(
            services: services,
            recordingId: '11111111-1111-4111-8111-111111111111',
            doc: DocType.soap,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The editor loaded the server's content into its reader — not the
      // placeholder, not an error state. (The redesign renders read mode
      // as SelectableText; TextField appears only after tapping Edit.)
      expect(tester.takeException(), isNull);
      expect(find.text('Could not load document'), findsNothing);
      expect(find.text('Not paired.'), findsNothing);
      expect(find.text('S: real server content'), findsOneWidget);
    });

    testWidgets(
      'recordings list renders a real offline cached list (${brightness.name})',
      (tester) async {
        final services = await makeServices();
        addTearDown(() => services.db.close());
        await services.offlineCache.replaceRecordings([
          const SyncRecording(
            id: 'cached-1',
            filename: 'consult-a.wav',
            createdAt: '2026-09-07T10:00:00Z',
            updatedAt: '2026-09-07T11:00:00Z',
            patientName: 'Test Patient',
            durationSeconds: 95,
          ),
        ]);

        // Every request fails at transport level — a genuinely unreachable
        // server — so the list must fall back to the SQLCipher cache.
        final overrides = _ContractOverrides(
          (req) => throw const SocketException('unreachable'),
        );
        HttpOverrides.global = overrides;
        addTearDown(() => HttpOverrides.global = null);
        await tester.pumpWidget(
          MaterialApp(
            theme: prodTheme(brightness),
            home: RecordingsScreen(services: services),
          ),
        );
        await tester.pumpAndSettle();

        // The cached row renders (title is patientName ?? filename) and the
        // offline banner is surfaced — not a blank screen, not a spinner
        // forever.
        expect(tester.takeException(), isNull);
        expect(find.text('Test Patient'), findsOneWidget);
        expect(
          find.text('Offline — showing cached recordings.'),
          findsOneWidget,
        );
      },
    );
  }
}

/// Answers `HttpClient` requests with real server-contract responses (or
/// transport failures) supplied by [handler].
class _ContractOverrides extends HttpOverrides {
  _ContractOverrides(this.handler);

  final _Response Function(HttpRequest req) handler;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _ContractClient(handler);
}

class _Response {
  _Response(this.status, this.body);
  final int status;
  final String body;
}

_Response _json(int status, Map<String, dynamic> body) =>
    _Response(status, jsonEncode(body));

class _ContractClient extends Fake implements HttpClient {
  _ContractClient(this.handler);
  final _Response Function(HttpRequest req) handler;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final fakeReq = _FakeRequest(url);
    final resp = handler(fakeReq); // may throw SocketException — propagates
    return _FakeClientRequest(url, resp);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeRequest extends Fake implements HttpRequest {
  _FakeRequest(this.uri);
  @override
  final Uri uri;
}

class _FakeClientRequest extends Fake implements HttpClientRequest {
  _FakeClientRequest(this.uri, this.resp);
  @override
  final Uri uri;
  final _Response resp;

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  bool bufferOutput = true;
  @override
  String get method => 'GET';
  @override
  HttpHeaders get headers => _FakeHeaders();
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<void> flush() async {}
  @override
  void write(Object? object) {}
  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async => _FakeClientResponse(uri, resp);
}

class _FakeClientResponse extends Fake implements HttpClientResponse {
  _FakeClientResponse(this.uri, this.resp);
  final Uri uri;
  final _Response resp;

  @override
  int get statusCode => resp.status;

  @override
  int get contentLength => resp.body.length;

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(resp.body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _m = {};

  @override
  List<String>? operator [](String name) => _m[name.toLowerCase()];

  @override
  String? value(String name) => _m[name.toLowerCase()]?.first;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _m[name.toLowerCase()] = value is List
        ? value.map((e) => '$e').toList()
        : ['$value'];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    (_m[name.toLowerCase()] ??= []).add('$value');
  }

  @override
  void forEach(void Function(String, List<String>) action) =>
      _m.forEach(action);

  @override
  ContentType? get contentType => ContentType.json;
}
