import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/patient_context.dart';
import '../../pairing/server_config_repository.dart';

/// Client-side + server-side stages of a recording ingest, in order.
enum IngestStage {
  creating,
  uploading,
  queued,
  transcribing,
  generatingSoap,
  completed,
  failed,
}

/// One progress event emitted during ingest.
class IngestEvent {
  const IngestEvent({required this.stage, this.recordingId, this.error});

  final IngestStage stage;
  final String? recordingId;
  final String? error;

  bool get isTerminal =>
      stage == IngestStage.completed || stage == IngestStage.failed;
}

/// Maps a server job stage string to the client [IngestStage] vocabulary.
IngestStage stageFromServer(String stage) {
  switch (stage) {
    case 'queued':
    case 'unknown':
      return IngestStage.queued;
    case 'transcribing':
      return IngestStage.transcribing;
    case 'generating_soap':
      return IngestStage.generatingSoap;
    case 'completed':
      return IngestStage.completed;
    case 'failed':
      return IngestStage.failed;
    default:
      // Per-doc-type stages (generating_referral, …) don't occur for the
      // soap pipeline, but map defensively to queued so the UI stays honest.
      return IngestStage.queued;
  }
}

/// Orchestrates the Phase 1 ingest: create recording → upload audio → trigger
/// SOAP generation → stream job stages over SSE.
///
/// Emits one [IngestEvent] per stage transition and terminates on
/// `completed`/`failed`. All network traffic is against the paired :11437
/// data API only; nothing is written to disk on this side.
class RecordingIngestService {
  RecordingIngestService({
    this.clientFactory = DataApiClient.forConfig,
    this.uuid = const Uuid(),
  });

  final DataApiClient Function(ServerConfig, String) clientFactory;
  final Uuid uuid;

  Stream<IngestEvent> run({
    required ServerConfig config,
    required String token,
    required Uint8List wav,
    required Duration duration,
    required String filename,
    PatientContext? patientContext,
  }) async* {
    final client = clientFactory(config, token);
    final id = uuid.v4();
    try {
      yield const IngestEvent(stage: IngestStage.creating);

      await client.createRecording(
        id: id,
        filename: filename,
        durationSeconds: duration.inMilliseconds / 1000.0,
      );

      yield const IngestEvent(stage: IngestStage.uploading);
      await client.uploadAudio(id, wav);

      await client.generateSoap(
        id,
        GenerateRequest(patientContext: patientContext?.toJson()),
      );
      // The server marks the job `queued` synchronously before returning 202,
      // so the SSE stream's first event carries `queued` (or later).

      await for (final snapshot in client.jobEvents(id)) {
        final stage = stageFromServer(snapshot.stage);
        if (stage == IngestStage.completed) {
          yield IngestEvent(stage: IngestStage.completed, recordingId: id);
          return;
        }
        if (stage == IngestStage.failed) {
          yield IngestEvent(
            stage: IngestStage.failed,
            recordingId: id,
            error: snapshot.error,
          );
          return;
        }
        yield IngestEvent(stage: stage, recordingId: id);
      }

      // SSE stream ended without a terminal event — surface a clean failure.
      yield IngestEvent(
        stage: IngestStage.failed,
        recordingId: id,
        error: 'job stream ended before completion',
      );
    } on DataApiException catch (e) {
      yield IngestEvent(
        stage: IngestStage.failed,
        recordingId: id,
        error: e.message,
      );
    } catch (e) {
      yield IngestEvent(
        stage: IngestStage.failed,
        recordingId: id,
        error: 'ingest failed',
      );
    } finally {
      client.close();
    }
  }
}
