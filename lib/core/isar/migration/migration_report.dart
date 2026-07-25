/// Result of a Drift→Isar migration run. Passed back to the caller so
/// main.dart can log it / show a one-time snackbar if desired.
class MigrationReport {
  final bool skipped;
  final Duration elapsed;
  final Map<String, int> sourceCounts;
  final Map<String, int> targetCounts;
  final String? error;

  const MigrationReport({
    required this.skipped,
    required this.elapsed,
    this.sourceCounts = const {},
    this.targetCounts = const {},
    this.error,
  });

  /// True if every source count matches its target count.
  bool get verified =>
      sourceCounts.length == targetCounts.length &&
      sourceCounts.entries.every(
        (e) => targetCounts[e.key] == e.value,
      );

  @override
  String toString() {
    if (skipped) return 'MigrationReport(skipped — already migrated)';
    final buf = StringBuffer('MigrationReport(${elapsed.inMilliseconds}ms');
    if (error != null) buf.write(', error: $error');
    buf.write(', verified: $verified)');
    for (final k in sourceCounts.keys) {
      buf.write('\n  $k: ${sourceCounts[k]} → ${targetCounts[k]}');
    }
    return buf.toString();
  }
}
