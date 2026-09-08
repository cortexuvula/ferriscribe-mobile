import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/app_bootstrap.dart';
import 'package:ferriscribe_mobile/features/home/consultations_screen.dart';
import 'package:ferriscribe_mobile/pairing/pairing_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';
import 'package:ferriscribe_mobile/storage/database/app_database.dart';
import 'package:ferriscribe_mobile/storage/key_store.dart';
import 'package:ferriscribe_mobile/storage/offline_cache_repository.dart';
import 'package:ferriscribe_mobile/ui/theme/app_theme.dart';

/// Client-side pagination (user request): the landing list reveals 10
/// rows at a time with a Load-more footer. Phone width (412dp), both
/// themes, the PRODUCTION widget driven through the real content-sync
/// contract shape (HttpOverrides, per codie's pattern).
void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'consultations list paginates 10 at a time (${brightness.name})',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final keys = MemoryKeyStore();
        final repo = ServerConfigRepository(db, keys);
        await repo.savePaired(
          label: 'phone',
          host: '127.0.0.1',
          pairingPort: 11436,
          dataPort: 11437,
          token: 't',
        );
        final services = AppServices(
          db: db,
          keyStore: keys,
          serverConfigRepository: repo,
          pairingService: PairingService(repository: repo),
          offlineCache: OfflineCacheRepository(db),
        );

        // Unique DESCENDING timestamps: consultation-0 is newest (first
        // row), consultation-24 the oldest (very last row).
        final recordings = List.generate(25, (i) {
          final t = DateTime.utc(
            2026,
            9,
            8,
          ).subtract(Duration(minutes: i + 1)).toIso8601String();
          return {
            'id':
                '00000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}',
            'filename': 'consultation-$i.wav',
            'created_at': t,
            'updated_at': t,
          };
        });
        final overrides = _ContractOverrides((req) {
          if (req.uri.path.endsWith('/v1/content/sync')) {
            return _json(200, {
              'recordings': recordings,
              'server_time': '2026-09-07T12:00:00Z',
              'has_more': false,
            });
          }
          return _json(404, {});
        });
        HttpOverrides.global = overrides;
        addTearDown(() => HttpOverrides.global = null);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            home: ConsultationsScreen(services: services, onUnpaired: () {}),
          ),
        );
        await tester.pumpAndSettle();

        final scroller = find.byKey(const Key('consultations-list'));

        Future<void> scrollTo(Finder f) async {
          for (var i = 0; i < 40; i++) {
            if (tester.any(f.hitTestable())) return;
            await tester.drag(scroller, const Offset(0, -250));
            await tester.pumpAndSettle();
          }
        }

        // (a) first page: footer says 15 remaining (25 - 10).
        await scrollTo(find.textContaining('Load more (15 remaining)'));
        expect(
          find.textContaining('Load more (15 remaining)'),
          findsOneWidget,
          reason: 'first page: 10 of 25, 15 remaining (${brightness.name})',
        );
        expect(tester.takeException(), isNull);

        // (c) tap footer 1 -> 20 of 25; plain label (5 < one page).
        await tester.tap(find.textContaining('Load more (15 remaining)'));
        await tester.pumpAndSettle();
        await scrollTo(find.text('Load more'));
        expect(
          find.text('Load more'),
          findsOneWidget,
          reason: 'second page footer (${brightness.name})',
        );
        expect(tester.takeException(), isNull);

        // Tap footer 2 -> all 25; footer gone; last row reachable.
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
        await scrollTo(find.textContaining('consultation-24'));
        expect(find.textContaining('consultation-24'), findsOneWidget);
        expect(find.textContaining('Load more'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

// Codie's proven contract-override harness (production_theme_widget_test).
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
