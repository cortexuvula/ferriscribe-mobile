/// Fixed, non-secret constants shared across the app.
///
/// Ports match the FerriScribe office server (verified against
/// `crates/sharing/src/orchestrator.rs` and `crates/sharing/src/qr.rs`):
/// `11436` pairing / discovery, `11437` data / vocab API.
library;

/// Custom URL scheme the desktop pairing QR encodes
/// (`ferriscribe://pair?...`).
const String kPairingScheme = 'ferriscribe';

/// Pairing router port (default) — hosts `/pair/enroll` and `GET /info`.
const int kDefaultPairingPort = 11436;

/// Data / vocab API port (default) — hosts `/v1/*`.
const int kDefaultDataPort = 11437;

/// Secure-storage keys. Values are the long-lived bearer token and the
/// SQLCipher database key. Neither is ever logged or written to the DB.
const String kTokenKey = 'ferriscribe.bearer_token';
const String kDbKeyKey = 'ferriscribe.sqlcipher_key';

/// SQLCipher key length in bytes (256-bit). Stored as hex in secure storage.
const int kDbKeyBytes = 32;

/// Method channel used for the native security hooks (Android MainActivity,
/// iOS AppDelegate).
const String kNativeChannel = 'com.ferriscribe.mobile/native';

/// Server-configured default label for a freshly paired device, used only as
/// the pre-filled value on the pairing screen (the user may change it).
const String kDefaultDeviceLabel = 'FerriScribe Mobile';
