import 'package:flutter/material.dart';

/// Compact download size meter for a manga panel while its image loads.
///
/// Shows received bytes (and total when Content-Length is known). Safe to use
/// per-panel — it does not gate preloading of neighboring pages.
class PageDownloadMeter extends StatelessWidget {
  const PageDownloadMeter({
    super.key,
    required this.cumulativeBytes,
    this.expectedTotalBytes,
    this.color = Colors.white70,
  });

  final int cumulativeBytes;
  final int? expectedTotalBytes;
  final Color color;

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return kb < 10
          ? '${kb.toStringAsFixed(1)} KB'
          : '${kb.round()} KB';
    }
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }

  bool get _hasTotal =>
      expectedTotalBytes != null && expectedTotalBytes! > 0;

  double? get _progress {
    if (!_hasTotal) return null;
    final total = expectedTotalBytes!;
    if (total <= 0) return null;
    return (cumulativeBytes / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final label = _hasTotal
        ? '${formatBytes(cumulativeBytes)} / ${formatBytes(expectedTotalBytes!)}'
        : cumulativeBytes > 0
            ? formatBytes(cumulativeBytes)
            : 'Loading…';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: color,
              value: _progress,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
