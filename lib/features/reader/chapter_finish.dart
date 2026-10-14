import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/security_prefs.dart';

/// One celebration per chapter, plus reading time summed across every day
/// that chapter was open.
class ChapterFinish {
  ChapterFinish._();

  static const _seenKey = 'chapter_finish_seen_v1';
  static const _openedKey = 'chapter_reader_opened_v1';
  static const _timeKey = 'chapter_reading_seconds_v1';

  static String bookKey(int chapterId) => 'b:$chapterId';
  static String novelKey(int chapterId) => 'n:$chapterId';

  /// Whether reaching the end of this chapter may celebrate.
  ///
  /// A chapter already marked read before it was ever opened in the reader
  /// is recorded as seen and will not celebrate. Opening a chapter (which
  /// stamps books as read immediately) does not count as that.
  static Future<bool> prepare({
    required String key,
    required bool alreadyMarkedRead,
  }) async {
    if (await SecurityPrefs.isIncognito()) return false;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? const <String>[];
    if (seen.contains(key)) return false;
    final opened = prefs.getStringList(_openedKey) ?? const <String>[];
    if (alreadyMarkedRead && !opened.contains(key)) {
      await _remember(prefs, _seenKey, key);
      return false;
    }
    await _remember(prefs, _openedKey, key);
    return true;
  }

  /// Marks the chapter finished. True only the first time.
  static Future<bool> consume(String key) async {
    if (await SecurityPrefs.isIncognito()) return false;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? const <String>[];
    if (seen.contains(key)) return false;
    await _remember(prefs, _seenKey, key);
    return true;
  }

  static Future<void> _remember(
    SharedPreferences prefs,
    String prefKey,
    String key,
  ) async {
    final current = prefs.getStringList(prefKey) ?? <String>[];
    if (current.contains(key)) return;
    await prefs.setStringList(prefKey, [...current, key]);
  }
}

/// Accumulates seconds a chapter stays open, across sessions and days.
class ChapterReadingClock {
  ChapterReadingClock._();

  static final ChapterReadingClock instance = ChapterReadingClock._();

  final Map<String, int> _saved = {};
  final Map<String, Stopwatch> _live = {};
  Timer? _flushTimer;
  String? _active;

  Future<void> switchTo(String key) async {
    if (await SecurityPrefs.isIncognito()) return;
    if (_active != null && _active != key) {
      await flush(_active!);
      _live.remove(_active);
    }
    _active = key;
    _saved[key] ??= await _read(key);
    _live.putIfAbsent(key, Stopwatch.new).start();
    _flushTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      final current = _active;
      if (current != null) unawaited(flush(current));
    });
  }

  Future<int> total(String key) async {
    _saved[key] ??= await _read(key);
    final live = _live[key]?.elapsed.inSeconds ?? 0;
    return (_saved[key] ?? 0) + live;
  }

  Future<void> flush(String key) async {
    if (await SecurityPrefs.isIncognito()) return;
    final watch = _live[key];
    if (watch == null) return;
    final add = watch.elapsed.inSeconds;
    if (add <= 0) return;
    watch
      ..reset()
      ..start();
    final next = (_saved[key] ?? await _read(key)) + add;
    _saved[key] = next;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ChapterFinish._timeKey);
    final map = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>);
    map[key] = next;
    await prefs.setString(ChapterFinish._timeKey, jsonEncode(map));
  }

  Future<int> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ChapterFinish._timeKey);
    if (raw == null || raw.isEmpty) return 0;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map[key] as num?)?.toInt() ?? 0;
  }
}

String formatChapterReadingTime(int seconds) {
  final safe = seconds < 1 ? 1 : seconds;
  if (safe < 60) {
    return safe == 1 ? '1 second' : '$safe seconds';
  }
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return hours == 1 ? '1 hour' : '$hours hours';
  return minutes == 1 ? '1 minute' : '$minutes minutes';
}

Future<void> showChapterFinishCelebration(
  BuildContext context, {
  required int chapterNumber,
  required int readingSeconds,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChapterFinishCelebration(
          chapterNumber: chapterNumber,
          readingSeconds: readingSeconds,
        );
      },
    ),
  );
}

class ChapterFinishCelebration extends StatefulWidget {
  const ChapterFinishCelebration({
    super.key,
    required this.chapterNumber,
    required this.readingSeconds,
  });

  final int chapterNumber;
  final int readingSeconds;

  @override
  State<ChapterFinishCelebration> createState() =>
      _ChapterFinishCelebrationState();
}

class _ChapterFinishCelebrationState extends State<ChapterFinishCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _strike;
  late final AnimationController _dance;
  bool _showCopy = false;
  bool _canDismiss = false;

  @override
  void initState() {
    super.initState();
    _strike = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _dance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    HapticFeedback.mediumImpact();
    _strike.forward().whenComplete(() {
      if (!mounted) return;
      _dance.repeat();
      // Let the flame dance, then flash the celebratory screen.
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _showCopy = true);
        HapticFeedback.lightImpact();
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _canDismiss = true);
        });
      });
    });
  }

  @override
  void dispose() {
    _strike.dispose();
    _dance.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!_canDismiss) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final time = formatChapterReadingTime(widget.readingSeconds);
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: const Color(0xFF140804),
        child: AnimatedBuilder(
          animation: Listenable.merge([_strike, _dance]),
          builder: (context, _) {
            final strike = reduce ? 1.0 : _strike.value;
            final dance = reduce ? 0.0 : _dance.value * math.pi * 2;
            final scale = Curves.easeOutBack.transform(strike.clamp(0.0, 1.0));
            final flash = strike < 0.35
                ? (strike / 0.35)
                : (1 - ((strike - 0.35) / 0.65)).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.15),
                      radius: 0.9,
                      colors: [
                        Color.lerp(
                          const Color(0xFF3A1208),
                          const Color(0xFFFFE7A0),
                          _showCopy ? 0.55 : flash * 0.85,
                        )!,
                        const Color(0xFF140804),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: _showCopy
                      ? const Alignment(0, -0.72)
                      : const Alignment(0, -0.05),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(-0.35)
                      ..rotateY(math.sin(dance) * 0.35),
                    child: Transform.scale(
                      scale: (_showCopy ? 0.42 : 1) * (0.08 + 0.92 * scale),
                      alignment: Alignment.bottomCenter,
                      child: CustomPaint(
                        size: const Size(220, 320),
                        painter: _FlamePainter(
                          dance: dance,
                          heat: strike,
                        ),
                      ),
                    ),
                  ),
                ),
                if (flash > 0.2 && !_showCopy)
                  ColoredBox(
                    color: const Color(0xFFFFF1C9).withValues(alpha: flash * 0.55),
                  ),
                if (_showCopy)
                  const ColoredBox(color: Color(0x66FFE7A0)),
                AnimatedOpacity(
                  opacity: _showCopy ? 1 : 0,
                  duration: const Duration(milliseconds: 280),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 72),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chapter ${widget.chapterNumber} Done!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFF6E4),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Spent $time reading this chapter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD7A1),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        if (_canDismiss) ...[
                          const SizedBox(height: 22),
                          const Text(
                            'Tap to continue',
                            style: TextStyle(
                              color: Color(0x99FFF6E4),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.dance, required this.heat});

  final double dance;
  final double heat;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.92);
    final height = size.height * (0.35 + 0.65 * heat);
    _lobe(
      canvas,
      base,
      height * 1.05,
      size.width * 0.42,
      dance,
      const [Color(0x00FF4A1A), Color(0xCCFF6A1A), Color(0xFFFFB020)],
      0,
    );
    _lobe(
      canvas,
      base,
      height * 0.82,
      size.width * 0.28,
      dance + 1.4,
      const [Color(0x00FF8A20), Color(0xEEFF9A2A), Color(0xFFFFF1A8)],
      1.2,
    );
    _lobe(
      canvas,
      base,
      height * 0.55,
      size.width * 0.14,
      dance + 2.2,
      const [Color(0x00FFF6D0), Color(0xFFFFF6C8), Color(0xFFFFFFFF)],
      0.6,
    );
    final spark = Paint()
      ..color = const Color(0xFFFFF8E8).withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(base.translate(0, -height * 0.42), 10 + 4 * math.sin(dance), spark);
  }

  void _lobe(
    Canvas canvas,
    Offset base,
    double height,
    double width,
    double phase,
    List<Color> colors,
    double sway,
  ) {
    final lean = math.sin(phase) * (10 + sway * 8);
    final pinch = 0.72 + 0.18 * math.sin(phase * 1.7);
    final path = Path()
      ..moveTo(base.dx - width, base.dy)
      ..cubicTo(
        base.dx - width * pinch + lean,
        base.dy - height * 0.35,
        base.dx - width * 0.15 + lean * 1.4,
        base.dy - height * 0.72,
        base.dx + lean * 0.4,
        base.dy - height,
      )
      ..cubicTo(
        base.dx + width * 0.2 + lean,
        base.dy - height * 0.68,
        base.dx + width * pinch + lean * 0.3,
        base.dy - height * 0.28,
        base.dx + width,
        base.dy,
      )
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
      ).createShader(Rect.fromLTWH(base.dx - width, base.dy - height, width * 2, height));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) {
    return oldDelegate.dance != dance || oldDelegate.heat != heat;
  }
}
