/// Latest application release metadata (Mihon [Release] parity).
class AppRelease {
  const AppRelease({
    required this.version,
    required this.info,
    required this.releaseLink,
    required this.downloadLink,
    this.downloadBytes,
  });

  final String version;
  final String info;
  final String releaseLink;
  final String downloadLink;

  /// GitHub asset `size` in bytes, when known.
  final int? downloadBytes;
}
