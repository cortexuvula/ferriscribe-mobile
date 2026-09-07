import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/api/data_api_client.dart';
import 'package:ferriscribe_mobile/core/api/models.dart';
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

  group('stageFromServer', () {
    test('maps the server vocabulary', () {
      expect(stageFromServer('queued'), IngestStage.queued);
      expect(stageFromServer('unknown'), IngestStage.queued);
      expect(stageFromServer('transcribing'), IngestStage.transcribing);
      expect(stageFromServer('generating_soap'), IngestStage.generatingSoap);
      expect(stageFromServer('completed'), IngestStage.completed);
      expect(stageFromServer('failed'), IngestStage.failed);
      expect(stageFromServer('generating_referral'), IngestStage.queued);
    });
  });
}
