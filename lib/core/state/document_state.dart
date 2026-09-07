/// §6.2 + §6.3 — document load results and per-recording cached
/// availability (design/MOBILE_REDESIGN.md).
///
/// Truth sources: the server's document GET (authoritative content +
/// field-revision timestamp) and the SQLCipher `CachedDocuments` table
/// (local cache time). These types carry both honestly so the UI can say
/// "cached copy from 10:12" instead of inferring from string fields.
library;

import '../api/models.dart';

/// Where a document's bytes came from.
enum DocumentSource { server, cache }

/// §6.2 — result of loading one document.
///
/// `updatedAt` is the SERVER's field-revision stamp when [source] is
/// server; the LOCAL cache-write time when [source] is cache.
class DocumentLoad {
  const DocumentLoad({
    required this.docType,
    required this.source,
    required this.updatedAt,
    this.content,
    this.cachedAvailable = false,
    this.cachedUpdatedAt,
  });

  final DocType docType;
  final DocumentSource source;

  /// Non-null when the document exists. Null = known absent (never
  /// generated, or generated-and-cleared).
  final String? content;
  final DateTime? updatedAt;

  /// Whether a cached copy exists in the encrypted store, independent of
  /// this load's source.
  final bool cachedAvailable;
  final DateTime? cachedUpdatedAt;

  bool get hasContent => content != null && content!.isNotEmpty;
}

/// §6.3 — which doc types have a locally cached copy for one recording.
///
/// Queried from CachedDocuments directly — NOT derived from the cached
/// SyncRecording's `fields` map, which is always empty offline (the cache
/// stores only metadata columns). `hasDoc` on a cached row lies; this
/// does not.
class CachedDocAvailability {
  const CachedDocAvailability({
    required this.recordingId,
    required this.available,
    required this.fetchedAt,
  });

  /// Recording the availability describes.
  final String recordingId;

  /// Doc types with a cached row, in canonical DocType order.
  final Set<DocType> available;

  /// When this availability snapshot was read from the cache (local time).
  final DateTime fetchedAt;

  bool has(DocType doc) => available.contains(doc);
  bool get isEmpty => available.isEmpty;
}

/// §6.5 — outcome of saving an edited document.
///
/// Server acknowledgement and cache write are tracked SEPARATELY, so a
/// cache failure after a successful server save never renders as "save
/// failed" (the server has the edit; only the offline copy is stale).
class DocumentSaveResult {
  const DocumentSaveResult({
    required this.serverAcknowledged,
    required this.cacheWritten,
  });

  /// The server accepted the PUT (204). Authoritative.
  final bool serverAcknowledged;

  /// The local encrypted cache was updated. Best-effort; false means the
  /// offline copy may be stale, NOT that the edit was lost.
  final bool cacheWritten;

  /// The edit is durably saved (server has it). Cache state is secondary.
  bool get saved => serverAcknowledged;
}

/// Parse an RFC 3339 stamp defensively; null when absent/unparseable.
DateTime? tryParseRfc3339(String? s) {
  if (s == null) return null;
  return DateTime.tryParse(s)?.toUtc();
}
