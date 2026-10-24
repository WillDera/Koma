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
  late final AnimationController _ignite;
  late final AnimationController _dance;
  late final AnimationController _burst;
  bool _showCopy = false;

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations;
    _ignite = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _dance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (reduce) {
      _ignite.value = 1;
      _showCopy = true;
      return;
    }
    HapticFeedback.lightImpact();
    _ignite.forward().whenComplete(() {
      if (!mounted) return;
      _dance.repeat();
      _burst.forward();
      setState(() => _showCopy = true);
    });
  }

  @override
  void dispose() {
    _ignite.dispose();
    _dance.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!_showCopy) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final time = formatChapterReadingTime(widget.readingSeconds);
    const cream = Color(0xFFFFF6EA);
    const amber = Color(0xFFE7C4A0);
    const ink = Color(0xFF140C09);
    return Material(
      color: ink,
      child: GestureDetector(
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.25),
              radius: 0.85,
              colors: [Color(0xFF3A2014), Color(0xFF140C09)],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_ignite, _dance, _burst]),
              builder: (context, _) {
                final ignite = reduce ? 1.0 : _ignite.value;
                final dance = reduce ? 0.0 : _dance.value * math.pi * 2;
                return Column(
                  children: [
                    const Spacer(flex: 2),
                    CustomPaint(
                      size: const Size(280, 340),
                      painter: _FlamePainter(
                        ignite: ignite,
                        dance: dance,
                        burst: reduce ? 0 : _burst.value,
                        still: reduce,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _showCopy ? 1 : 0,
                      duration: const Duration(milliseconds: 420),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            decoration: TextDecoration.none,
                            decorationColor: Color(0x00000000),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Chapter ${widget.chapterNumber} complete!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  letterSpacing: -0.4,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Spent $time reading this chapter.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Opacity(
                                opacity: _showCopy ? 1 : 0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A1A12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFF6A4A32),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: cream,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({
    required this.ignite,
    required this.dance,
    required this.burst,
    required this.still,
  });

  final double ignite;
  final double dance;
  final double burst;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final growth = Curves.easeOutCubic.transform(ignite.clamp(0.0, 1.0));
    final base = Offset(size.width / 2, size.height * 0.9);
    final breath = still ? 1.0 : 0.96 + 0.04 * math.sin(dance);
    final height = size.height * 0.72 * (0.12 + 0.88 * growth) * breath;
    final body = size.width * 0.22 * (0.2 + 0.8 * growth);

    _halo(canvas, base, height, growth);
    _tongue(
      canvas,
      base: base,
      height: height,
      halfWidth: body * 1.15,
      lean: still ? 6 : 14 * math.sin(dance * 0.7),
      phase: dance,
      asymmetry: -0.18,
      colors: const [
        Color(0x00C45A12),
        Color(0x99E07A28),
        Color(0xCCF0A04A),
      ],
    );
    _tongue(
      canvas,
      base: base.translate(body * 0.28, 4),
      height: height * 0.72,
      halfWidth: body * 0.62,
      lean: still ? -4 : -10 * math.sin(dance * 1.1 + 1),
      phase: dance + 1.4,
      asymmetry: 0.22,
      colors: const [
        Color(0x00E87820),
        Color(0xDDF08A32),
        Color(0xEEFFC56A),
      ],
    );
    _tongue(
      canvas,
      base: base.translate(-body * 0.22, 2),
      height: height * 0.58,
      halfWidth: body * 0.48,
      lean: still ? 3 : 8 * math.sin(dance * 1.4 + 2.2),
      phase: dance + 2.1,
      asymmetry: -0.08,
      colors: const [
        Color(0x00FFB04A),
        Color(0xEEFFD27A),
        Color(0xFFFFF3C4),
      ],
    );
    _tongue(
      canvas,
      base: base,
      height: height * 0.42,
      halfWidth: body * 0.22,
      lean: still ? 0 : 4 * math.sin(dance * 1.8),
      phase: dance + 0.4,
      asymmetry: 0.05,
      colors: const [
        Color(0x00FFF6D8),
        Color(0xEEFFF8E4),
        Color(0xFFFFFFFF),
      ],
    );
    if (!still && growth > 0.4) {
      _embers(canvas, base, height, body);
    }
    if (!still && burst > 0 && burst < 1) {
      _sparks(canvas, base, height);
    }
  }

  void _halo(Canvas canvas, Offset base, double height, double growth) {
    final paint = Paint()
      ..color = const Color(0xFFFF9A3C).withValues(alpha: 0.22 * growth)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -height * 0.42),
        width: height * 0.7,
        height: height * 0.85,
      ),
      paint,
    );
  }

  void _tongue(
    Canvas canvas, {
    required Offset base,
    required double height,
    required double halfWidth,
    required double lean,
    required double phase,
    required double asymmetry,
    required List<Color> colors,
  }) {
    const steps = 28;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final side = _edge(t, halfWidth, lean, phase, asymmetry, left: true);
      final point = Offset(base.dx + side, base.dy - height * _rise(t));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final t = i / steps;
      final side = _edge(t, halfWidth, lean, phase, asymmetry, left: false);
      path.lineTo(base.dx + side, base.dy - height * _rise(t));
    }
    path.close();
    final rect = Rect.fromCenter(
      center: base.translate(0, -height * 0.45),
      width: halfWidth * 3.2,
      height: height * 1.15,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.72),
        radius: 0.95,
        colors: colors,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  /// 0 at the wick, 1 at the tip. The lower third rises slowly so the body
  /// stays rounded instead of shooting up in a straight wedge.
  double _rise(double t) => math.pow(t, 0.82).toDouble();

  double _edge(
    double t,
    double halfWidth,
    double lean,
    double phase,
    double asymmetry, {
    required bool left,
  }) {
    final belly = math.sin(math.pi * math.pow(t, 0.72));
    final taper = math.pow(1 - t, 0.42);
    final wave = math.sin(phase + t * 6.5) * halfWidth * 0.07 * t;
    final hook = lean * t * t;
    final signed = left ? -1.0 : 1.0;
    final bias = 1 + asymmetry * signed;
    return signed * halfWidth * belly * taper * bias + wave + hook;
  }

  void _embers(Canvas canvas, Offset base, double height, double body) {
    final paint = Paint();
    for (var i = 0; i < 9; i++) {
      final seed = i * 1.37;
      final life = (dance / (math.pi * 2) * (0.7 + (i % 3) * 0.15) + seed) % 1.0;
      final x = base.dx + math.sin(seed * 4 + dance) * body * (0.15 + life);
      final y = base.dy - height * (0.25 + life * 0.85);
      paint.color = const Color(0xFFFFC56A).withValues(alpha: (1 - life) * 0.75);
      canvas.drawCircle(Offset(x, y), 1.1 + (i % 3) * 0.45, paint);
    }
  }

  void _sparks(Canvas canvas, Offset base, double height) {
    final paint = Paint();
    final origin = base.translate(0, -height * 0.55);
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2 + 0.4;
      final dist = 18 + burst * (36 + (i % 4) * 10);
      final alpha = (1 - burst) * 0.8;
      paint.color = const Color(0xFFFFE3A3).withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(
          origin.dx + math.cos(angle) * dist,
          origin.dy + math.sin(angle) * dist * 0.72 - burst * 16,
        ),
        1.4 * (1 - burst * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) {
    return oldDelegate.ignite != ignite ||
        oldDelegate.dance != dance ||
        oldDelegate.burst != burst ||
        oldDelegate.still != still;
  }
}
