import 'package:flutter_test/flutter_test.dart';

import 'package:ferriscribe_mobile/core/state/ingest_state.dart';
import 'package:ferriscribe_mobile/features/recording/recording_ingest_service.dart';

void main() {
  group('IngestPresentation fold logic (record screen state machine)', () {
    IngestPresentation fold(IngestEvent event, IngestPresentation prior) {
      // Mirrors _RecordScreenState._fold's transitions.
      switch (event.stage) {
        case IngestStage.creating:
          return IngestPresentation(
            lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
            recordingId: event.recordingId ?? prior.recordingId,
            audioRecoverable: true,
          );
        case IngestStage.uploading:
          return IngestPresentation(
            lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
            recordingId: event.recordingId ?? prior.recordingId,
            audioRecoverable: true,
          );
        case IngestStage.queued:
          return IngestPresentation(
            lastAcknowledgedStage: IngestAcknowledgedStage.generationQueued,
            recordingId: event.recordingId ?? prior.recordingId,
            uploadAcknowledged: true,
            generationAccepted: true,
            audioRecoverable: false,
          );
        case IngestStage.transcribing:
          return IngestPresentation(
            lastAcknowledgedStage: IngestAcknowledgedStage.transcribing,
            recordingId: event.recordingId ?? prior.recordingId,
            uploadAcknowledged: true,
            generationAccepted: true,
          );
        case IngestStage.generatingSoap:
          return IngestPresentation(
            lastAcknowledgedStage: IngestAcknowledgedStage.generatingSoap,
            recordingId: event.recordingId ?? prior.recordingId,
            uploadAcknowledged: true,
            generationAccepted: true,
          );
        case IngestStage.completed:
          return IngestPresentation(
            lastAcknowledgedStage: IngestAcknowledgedStage.completed,
            recordingId: event.recordingId ?? prior.recordingId,
            uploadAcknowledged: true,
            generationAccepted: true,
          );
        case IngestStage.failed:
          return IngestPresentation(
            lastAcknowledgedStage: prior.lastAcknowledgedStage,
            recordingId: event.recordingId ?? prior.recordingId,
            uploadAcknowledged: prior.uploadAcknowledged,
            generationAccepted: prior.generationAccepted,
            failure: IngestFailure(
              phase: IngestFailurePhase.unknown,
              detail: event.error ?? 'failed',
            ),
            audioRecoverable: false,
          );
      }
    }

    IngestPresentation initial = const IngestPresentation(
      lastAcknowledgedStage: IngestAcknowledgedStage.creatingAcknowledged,
      recordingId: '',
    );

    test('happy path advances acknowledged stages and acks separately', () {
      var p = initial;
      p = fold(
        IngestEvent(stage: IngestStage.creating, recordingId: 'rec-1'),
        p,
      );
      expect(p.recordingId, 'rec-1');
      expect(p.uploadAcknowledged, isFalse);

      p = fold(
        IngestEvent(stage: IngestStage.uploading, recordingId: 'rec-1'),
        p,
      );
      // Upload in flight — not yet acknowledged.
      expect(p.uploadAcknowledged, isFalse);

      p = fold(IngestEvent(stage: IngestStage.queued, recordingId: 'rec-1'), p);
      expect(p.lastAcknowledgedStage, IngestAcknowledgedStage.generationQueued);
      expect(p.uploadAcknowledged, isTrue);
      expect(p.generationAccepted, isTrue);
      expect(p.audioRecoverable, isFalse, reason: 'server owns the bytes now');

      p = fold(
        IngestEvent(stage: IngestStage.transcribing, recordingId: 'rec-1'),
        p,
      );
      expect(p.lastAcknowledgedStage, IngestAcknowledgedStage.transcribing);

      p = fold(
        IngestEvent(stage: IngestStage.completed, recordingId: 'rec-1'),
        p,
      );
      expect(p.lastAcknowledgedStage, IngestAcknowledgedStage.completed);
      expect(p.isTerminal, isTrue);
      expect(p.failure, isNull);
    });

    test('failure preserves prior acknowledgements and sets failure fact', () {
      var p = initial;
      p = fold(
        IngestEvent(stage: IngestStage.creating, recordingId: 'rec-1'),
        p,
      );
      p = fold(IngestEvent(stage: IngestStage.queued, recordingId: 'rec-1'), p);
      p = fold(
        IngestEvent(
          stage: IngestStage.failed,
          recordingId: 'rec-1',
          error: 'generate (HTTP 500)',
        ),
        p,
      );
      expect(p.isTerminal, isTrue);
      expect(p.failure, isNotNull);
      expect(p.uploadAcknowledged, isTrue, reason: 'upload ack survives');
      expect(
        p.lastAcknowledgedStage,
        IngestAcknowledgedStage.generationQueued,
        reason: 'last acknowledged stage is preserved, not "failed"',
      );
    });

    test(
      'upload failure: nothing acknowledged, audio recoverable until dropped',
      () {
        var p = initial;
        p = fold(
          IngestEvent(stage: IngestStage.creating, recordingId: 'rec-2'),
          p,
        );
        p = fold(
          IngestEvent(
            stage: IngestStage.failed,
            recordingId: 'rec-2',
            error: 'audio upload failed (HTTP 0)',
          ),
          p,
        );
        expect(p.uploadAcknowledged, isFalse);
        expect(p.generationAccepted, isFalse);
        expect(p.failure, isNotNull);
        expect(
          p.audioRecoverable,
          isFalse,
          reason: 'presentation drops recoverability on failure fold',
        );
      },
    );
  });

  group('IngestAcknowledgedStage vocabulary', () {
    test('server stages fold to acknowledged stages', () {
      expect(
        acknowledgedFromServerStage('queued'),
        IngestAcknowledgedStage.generationQueued,
      );
      expect(
        acknowledgedFromServerStage('transcribing'),
        IngestAcknowledgedStage.transcribing,
      );
      expect(
        acknowledgedFromServerStage('generating_soap'),
        IngestAcknowledgedStage.generatingSoap,
      );
      expect(
        acknowledgedFromServerStage('completed'),
        IngestAcknowledgedStage.completed,
      );
    });

    test('non-SOAP and failure stages are not ingest stages', () {
      expect(acknowledgedFromServerStage('generating_referral'), isNull);
      expect(acknowledgedFromServerStage('failed'), isNull);
      expect(acknowledgedFromServerStage('unknown'), isNull);
    });
  });

  group('SoapNavigationTarget', () {
    test('carries the real recording id', () {
      const t = SoapNavigationTarget(recordingId: 'abc-123');
      expect(t.recordingId, 'abc-123');
    });
  });
}
