/// §6.4 — ingest presentation state (design/MOBILE_REDESIGN.md).
///
/// The existing IngestEvent stream proves less than the UI needs to say:
/// a `completed` SSE stage does not prove the SOAP row is fetchable, a
/// dropped connection does not prove failure, and "audio recoverable" is
/// only true while the WAV buffer is still in RAM. This state machine
/// tracks each fact separately and never invents success — reconciliation
/// goes through `GET /v1/jobs/{id}` and the document endpoints.
library;

import '../api/data_api_client.dart';

/// Every presentation fact about one recording-ingest run.
class IngestPresentation {
  const IngestPresentation({
    required this.lastAcknowledgedStage,
    required this.recordingId,
    this.uploadAcknowledged = false,
    this.generationAccepted = false,
    this.failure,
    this.audioRecoverable = false,
  });

  /// Last stage the SERVER or the local pipeline acknowledged (never a
  /// speculative next step).
  final IngestAcknowledgedStage lastAcknowledgedStage;

  /// Real server recording id; empty until `POST /v1/recordings` returned
  /// 201 (client-minted ids are used optimistically before that).
  final String recordingId;

  /// The audio PUT returned 2xx — the server owns the (encrypted) bytes.
  final bool uploadAcknowledged;

  /// The generate call returned 202 — the server queued the job.
  final bool generationAccepted;

  /// Set only on an acknowledged failure (SSE `failed`, non-2xx ack, or
  /// job-status reconciliation returning `failed`). Null otherwise —
  /// an interrupted stream is NOT a failure.
  final IngestFailure? failure;

  /// Audio is still recoverable for a retry: the WAV buffer is in RAM.
  /// False once discarded (user confirmed discard, or buffers freed).
  /// The presentation layer owns this flag; this type only carries it.
  final bool audioRecoverable;

  bool get isTerminal =>
      lastAcknowledgedStage == IngestAcknowledgedStage.completed ||
      failure != null;
}

/// Stages the ingest pipeline can have ACKNOWLEDGED. Distinct from
/// IngestStage: no `creating` (that's local intent, pre-ack).
enum IngestAcknowledgedStage {
  creatingAcknowledged('recording row created'),
  uploaded('audio uploaded'),
  generationQueued('generation queued'),
  transcribing('transcribing'),
  generatingSoap('generating soap'),
  completed('completed');

  const IngestAcknowledgedStage(this.label);
  final String label;
}

/// An acknowledged failure, with provenance.
class IngestFailure {
  const IngestFailure({
    required this.phase,
    required this.detail,
    this.serverJobStage,
  });

  final IngestFailurePhase phase;

  /// Non-PHI technical detail (status codes, stage labels). Never
  /// transcript or patient content.
  final String detail;

  /// The server's own terminal stage when reconciliation observed it.
  final String? serverJobStage;
}

enum IngestFailurePhase { create, upload, generate, job, unknown }

/// Fold an acknowledged stage string from the server job vocabulary into
/// the presentation vocabulary. Unknown strings (e.g. per-doc-type
/// generation stages) are NOT ingest stages for SOAP — they map to null
/// and must not be shown as SOAP progress.
IngestAcknowledgedStage? acknowledgedFromServerStage(String stage) {
  switch (stage) {
    case 'queued':
      return IngestAcknowledgedStage.generationQueued;
    case 'transcribing':
      return IngestAcknowledgedStage.transcribing;
    case 'generating_soap':
      return IngestAcknowledgedStage.generatingSoap;
    case 'completed':
      return IngestAcknowledgedStage.completed;
    default:
      return null; // 'failed' is a failure, not a stage; others aren't SOAP-ingest stages
  }
}

/// §6.6 navigation target: open THIS recording's SOAP immediately.
class SoapNavigationTarget {
  const SoapNavigationTarget({required this.recordingId});
  final String recordingId;
}

/// Reconcile a possibly-interrupted ingest against the server's job
/// registry. Returns the presentation state the UI should hold.
///
/// - Job unknown (404 → null snapshot): server restarted or job pruned —
///   the truth is the DOCUMENT row, not the registry.
/// - Job `failed`: acknowledged failure.
/// - Job `completed` / live stage: reflect it.
/// - Network error: NOT a failure — return the prior state unchanged.
Future<IngestPresentation> reconcileIngest({
  required DataApiClient client,
  required IngestPresentation prior,
}) async {
  final rid = prior.recordingId;
  if (rid.isEmpty) return prior; // never created — nothing to reconcile

  try {
    final snap = await client.jobStatus(rid);
    if (snap == null) {
      // Registry has no word. If the pipeline had acknowledged completion,
      // trust it; otherwise the document endpoints remain the truth and
      // the UI keeps the last acknowledged stage (no invented success).
      return prior;
    }
    if (snap.stage == 'failed') {
      return IngestPresentation(
        lastAcknowledgedStage: prior.lastAcknowledgedStage,
        recordingId: rid,
        uploadAcknowledged: prior.uploadAcknowledged,
        generationAccepted: prior.generationAccepted,
        failure: IngestFailure(
          phase: IngestFailurePhase.job,
          detail: 'job failed',
          serverJobStage: snap.stage,
        ),
        audioRecoverable: false,
      );
    }
    final acked = acknowledgedFromServerStage(snap.stage);
    if (acked == null) return prior;
    return IngestPresentation(
      lastAcknowledgedStage: acked,
      recordingId: rid,
      uploadAcknowledged: true,
      generationAccepted: true,
      audioRecoverable: false,
    );
  } on DataApiException {
    // Registry unreachable: keep prior facts. Not a failure.
    return prior;
  }
}
