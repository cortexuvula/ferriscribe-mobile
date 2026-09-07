import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
import 'package:ferriscribe_mobile/core/state/ingest_state.dart'
    show IngestFailurePhase;
import 'package:ferriscribe_mobile/features/recording/recording_ingest_service.dart';
import 'package:ferriscribe_mobile/pairing/server_config_repository.dart';

class _FakeClient extends DataApiClient {
  _FakeClient(this.stages) : super(host: 'localhost', port: 1, token: 'x');

  final List<String> stages;

  @override
  Future<CreatedRecording> createRecording({
    required String id,
    required String filename,
    double? durationSeconds,
  }) async => CreatedRecording(id: id, createdAt: 'now');

  @override
  Future<int> uploadAudio(String recordingId, List<int> wavBytes) async =>
      wavBytes.length;

  @override
  Future<void> generateSoap(
    String recordingId, [
    GenerateRequest? request,
  ]) async {}

  @override
  Stream<JobSnapshot> jobEvents(String recordingId) async* {
    for (final stage in stages) {
      yield JobSnapshot(recordingId: recordingId, stage: stage, updatedAt: 't');
    }
  }

  @override
  void close() {}
}

void main() {
  group('RecordingIngestService', () {
    test('emits creating→uploading→server stages→completed', () async {
      final service = RecordingIngestService(
        clientFactory: (_, _) => _FakeClient([
          'queued',
          'transcribing',
          'generating_soap',
          'completed',
        ]),
      );

      final events = await service
          .run(
            config: ServerConfig(
              label: 'phone',
              host: 'clinic.tail-abc.ts.net',
              pairingPort: 11436,
              dataPort: 11437,
              pairedAt: DateTime(2026, 9, 6),
            ),
            token: 't',
            wav: Uint8List(100),
            duration: const Duration(seconds: 3),
            filename: 'Consultation',
          )
          .toList();

      expect(events.map((e) => e.stage).toList(), [
        IngestStage.creating,
        IngestStage.uploading,
        IngestStage.queued,
        IngestStage.transcribing,
        IngestStage.generatingSoap,
        IngestStage.completed,
      ]);
      expect(events.last.recordingId, isNotNull);
    });

    test('terminates on a failed stage with error', () async {
      final service = RecordingIngestService(
        clientFactory: (_, _) => _FakeClient(['queued', 'failed']),
      );

      final events = await service
          .run(
            config: ServerConfig(
              label: 'phone',
              host: 'h',
              pairingPort: 11436,
              dataPort: 11437,
              pairedAt: DateTime(2026, 9, 6),
            ),
            token: 't',
            wav: Uint8List(0),
            duration: Duration.zero,
            filename: 'f',
          )
          .toList();

      expect(events.last.stage, IngestStage.failed);
      expect(events.last.recordingId, isNotNull);
    });
  });

  group('knownServerStage', () {
    test('unknown stages are null, not SOAP progress', () {
      expect(knownServerStage('generating_referral'), isNull);
      expect(knownServerStage('unknown'), isNull);
      expect(knownServerStage('weird-new-stage'), isNull);
      expect(knownServerStage('queued'), IngestStage.queued);
    });
  });

  group('failure phase is carried from the throw site', () {
    test('upload failure carries IngestFailurePhase.upload', () async {
      final service = RecordingIngestService(
        clientFactory: (_, _) =>
            _FailingClient(uploadFails: true, stages: const []),
      );

      final events = await service
          .run(
            config: ServerConfig(
              label: 'phone',
              host: 'h',
              pairingPort: 11436,
              dataPort: 11437,
              pairedAt: DateTime(2026, 9, 7),
            ),
            token: 't',
            wav: Uint8List(10),
            duration: Duration.zero,
            filename: 'f',
          )
          .toList();

      final failure = events.lastWhere((e) => e.stage == IngestStage.failed);
      expect(failure.failurePhase, IngestFailurePhase.upload);
    });

    test('create failure carries IngestFailurePhase.create', () async {
      final service = RecordingIngestService(
        clientFactory: (_, _) =>
            _FailingClient(createFails: true, stages: const []),
      );

      final events = await service
          .run(
            config: ServerConfig(
              label: 'phone',
              host: 'h',
              pairingPort: 11436,
              dataPort: 11437,
              pairedAt: DateTime(2026, 9, 7),
            ),
            token: 't',
            wav: Uint8List(10),
            duration: Duration.zero,
            filename: 'f',
          )
          .toList();

      final failure = events.lastWhere((e) => e.stage == IngestStage.failed);
      expect(failure.failurePhase, IngestFailurePhase.create);
    });

    test(
      'SSE ending without terminal event is interrupted, not failed',
      () async {
        // Stages stream ends cleanly after a non-terminal stage — no
        // completed/failed ever arrives.
        final service = RecordingIngestService(
          clientFactory: (_, _) => _FailingClient(
            stages: const ['queued', 'transcribing'],
            sseEndsSilently: true,
          ),
        );

        final events = await service
            .run(
              config: ServerConfig(
                label: 'phone',
                host: 'h',
                pairingPort: 11436,
                dataPort: 11437,
                pairedAt: DateTime(2026, 9, 7),
              ),
              token: 't',
              wav: Uint8List(10),
              duration: Duration.zero,
              filename: 'f',
            )
            .toList();

        expect(
          events.last.stage,
          IngestStage.interrupted,
          reason: 'a dropped stream must never be reported as failure',
        );
        expect(events.any((e) => e.stage == IngestStage.failed), isFalse);
      },
    );
  });
}

/// Test double that fails specific calls or ends SSE silently.
class _FailingClient extends DataApiClient {
  _FailingClient({
    this.createFails = false,
    this.uploadFails = false,
    this.sseEndsSilently = false,
    required this.stages,
  }) : super(host: 'localhost', port: 1, token: 'x');

  final bool createFails;
  final bool uploadFails;
  final bool sseEndsSilently;
  final List<String> stages;

  @override
  Future<CreatedRecording> createRecording({
    required String id,
    required String filename,
    double? durationSeconds,
  }) async {
    if (createFails) {
      throw const DataApiException(0, 'create recording failed');
    }
    return CreatedRecording(id: id, createdAt: 'now');
  }

  @override
  Future<int> uploadAudio(String recordingId, List<int> wavBytes) async {
    if (uploadFails) {
      throw const DataApiException(0, 'audio upload failed');
    }
    return wavBytes.length;
  }

  @override
  Future<void> generateSoap(
    String recordingId, [
    GenerateRequest? request,
  ]) async {
    if (sseEndsSilently && stages.isEmpty) {
      throw const DataApiException(0, 'generate soap failed');
    }
  }

  @override
  Stream<JobSnapshot> jobEvents(String recordingId) async* {
    for (final stage in stages) {
      yield JobSnapshot(recordingId: recordingId, stage: stage, updatedAt: 't');
    }
    // Ends without a terminal event when sseEndsSilently.
  }

  @override
  void close() {}
}
