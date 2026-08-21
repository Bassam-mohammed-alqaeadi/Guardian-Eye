/// FS-016 — compile-time application version.
///
/// A deliberate compile-time constant instead of a runtime package lookup:
/// the startup path and the what's-new card stream are local-only and must
/// never depend on platform channels, package metadata, or network during
/// cold start. Bumped by the release flow; the whats-new engine compares it
/// against dismissed versions stored in `app_identity`.
const String appVersion = '1.0.0';
