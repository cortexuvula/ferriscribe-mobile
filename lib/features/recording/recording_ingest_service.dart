import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/api/data_api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/patient_context.dart';
import '../../core/state/ingest_state.dart' show IngestFailurePhase;
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

  /// The SSE stream ended without a terminal event — NOT a failure fact.
  /// The UI must reconcile via job status; the server job may still be
  /// running or completed. Never render as `failed`.
  interrupted,
}

/// One progress event emitted during ingest.
class IngestEvent {
  const IngestEvent({
    required this.stage,
    this.recordingId,
    this.error,
    this.failurePhase,
  });

  final IngestStage stage;
  final String? recordingId;

  /// Non-PHI technical detail (status codes, stage labels).
  final String? error;

  /// Failure phase (core/state/ingest_state.dart), set only for
  /// [IngestStage.failed] events — carried from the throw site so the UI
  /// never infers it from error text.
  final IngestFailurePhase? failurePhase;

  bool get isTerminal =>
      stage == IngestStage.completed ||
      stage == IngestStage.failed ||
      stage == IngestStage.interrupted;
}

/// Maps a KNOWN server job stage string to the client vocabulary. Unknown
/// strings (per-doc-type generation stages, `unknown`) map to null — the
/// SOAP-ingest UI must not present them as SOAP progress.
IngestStage? knownServerStage(String stage) {
  switch (stage) {
    case 'queued':
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
      return null;
  }
}

/// Legacy mapper retained for callers that need a non-null result; unknown
/// stages (incl. `unknown`) map to queued without inventing progress.
IngestStage stageFromServer(String stage) =>
    knownServerStage(stage) ?? IngestStage.queued;

/// Orchestrates the ingest: create recording → upload audio → trigger SOAP
/// generation → stream job stages over SSE.
///
/// Failure events carry their [IngestFailurePhase] from the throw site. An
/// SSE stream that ends without a terminal event yields
/// [IngestStage.interrupted] — never a failure.
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
      try {
        await client.createRecording(
          id: id,
          filename: filename,
          durationSeconds: duration.inMilliseconds / 1000.0,
        );
      } on DataApiException catch (e) {
        yield _failed(id, e, IngestFailurePhase.create);
        return;
      }

      yield const IngestEvent(stage: IngestStage.uploading);
      try {
        await client.uploadAudio(id, wav);
      } on DataApiException catch (e) {
        yield _failed(id, e, IngestFailurePhase.upload);
        return;
      }

      try {
        await client.generateSoap(
          id,
          GenerateRequest(patientContext: patientContext?.toJson()),
        );
      } on DataApiException catch (e) {
        yield _failed(id, e, IngestFailurePhase.generate);
        return;
      }
      // The server marks the job `queued` synchronously before returning 202,
      // so the SSE stream's first event carries `queued` (or later).

      await for (final snapshot in client.jobEvents(id)) {
        final stage = knownServerStage(snapshot.stage);
        if (stage == null) continue; // not a SOAP-ingest stage — ignore
        if (stage == IngestStage.completed) {
          yield IngestEvent(stage: IngestStage.completed, recordingId: id);
          return;
        }
        if (stage == IngestStage.failed) {
          yield IngestEvent(
            stage: IngestStage.failed,
            recordingId: id,
            error: snapshot.error,
            failurePhase: IngestFailurePhase.job,
          );
          return;
        }
        yield IngestEvent(stage: stage, recordingId: id);
      }

      // SSE ended without a terminal event. NOT a failure: the server job
      // may still complete. The UI reconciles via job status.
      yield IngestEvent(stage: IngestStage.interrupted, recordingId: id);
    } catch (e) {
      yield const IngestEvent(
        stage: IngestStage.failed,
        error: 'ingest failed',
        failurePhase: IngestFailurePhase.job,
      );
    } finally {
      client.close();
    }
  }

  IngestEvent _failed(
    String id,
    DataApiException e,
    IngestFailurePhase phase,
  ) => IngestEvent(
    stage: IngestStage.failed,
    recordingId: id,
    error: e.message,
    failurePhase: phase,
  );
}
