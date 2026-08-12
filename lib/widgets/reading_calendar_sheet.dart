import 'package:flutter/material.dart';

import '../core/models/reading_stat.dart';
import '../core/services/stats_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';

/// Opens the complete, month-by-month reading activity calendar.
void showReadingCalendarSheet(BuildContext context, StatsService statsService) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReadingCalendarSheet(statsService: statsService),
  );
}

class _ReadingCalendarSheet extends StatefulWidget {
  final StatsService statsService;

  const _ReadingCalendarSheet({required this.statsService});

  @override
  State<_ReadingCalendarSheet> createState() => _ReadingCalendarSheetState();
}

class _ReadingCalendarSheetState extends State<_ReadingCalendarSheet> {
  DateTime _month = _monthStart(DateTime.now());
  Map<DateTime, int> _minutesByDay = const {};
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    final end = DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);
    final stats = await widget.statsService.getStats(_month, end);
    if (!mounted) return;
    setState(() {
      _minutesByDay = {
        for (final ReadingStat stat in stats)
          _dayStart(stat.date): stat.readingTimeSeconds ~/ 60,
      };
      _selectedDay = null;
      _loading = false;
    });
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final selectedMinutes = _selectedDay == null
        ? null
        : _minutesByDay[_selectedDay] ?? 0;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.86),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textTertiary.withValues(alpha: 0.55),
                  borderRadius: AppSpacing.brPill,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Reading atlas',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Books and manga share one reading trail. Seven minutes starts a light day.',
              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _MonthButton(
                  icon: Icons.chevron_left_rounded,
                  label: 'Previous month',
                  onTap: () => _moveMonth(-1),
                ),
                Expanded(
                  child: Text(
                    _monthLabel(_month),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _MonthButton(
                  icon: Icons.chevron_right_rounded,
                  label: 'Next month',
                  onTap: _isCurrentMonth ? null : () => _moveMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _WeekdayLabels(),
            const SizedBox(height: 7),
            if (_loading)
              const SizedBox(
                height: 264,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _MonthGrid(
                month: _month,
                minutesByDay: _minutesByDay,
                selectedDay: _selectedDay,
                onDaySelected: (day) => setState(() => _selectedDay = day),
              ),
            const SizedBox(height: 18),
            _ActivityLegend(),
            if (selectedMinutes != null) ...[
              const SizedBox(height: 18),
              _DayDetail(day: _selectedDay!, minutes: selectedMinutes),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, int> minutesByDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthGrid({
    required this.month,
    required this.minutesByDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstWeekday = month.weekday - 1;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
      for (var day = 1; day <= lastDay; day++)
        _CalendarDay(
          day: DateTime(month.year, month.month, day),
          minutes: minutesByDay[DateTime(month.year, month.month, day)] ?? 0,
          selected: selectedDay == DateTime(month.year, month.month, day),
          onTap: () => onDaySelected(DateTime(month.year, month.month, day)),
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1,
      children: cells,
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime day;
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.day,
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final level = _activityLevel(minutes);
    final today = _dayStart(day) == _dayStart(DateTime.now());
    final isFire = level == _ActivityLevel.fire;
    final (fill, foreground) = _dayColors(c, level);
    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selected
              ? c.textPrimary
              : today
              ? c.accent.withValues(alpha: 0.8)
              : Colors.transparent,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: isFire
            ? [BoxShadow(color: const Color(0xFFFF6A00).withValues(alpha: 0.38), blurRadius: 13, spreadRadius: 1)]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (isFire) const Positioned(top: -8, child: _FireMarker()),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '${_monthLabel(day)} ${day.day}: $minutes minutes read',
      child: AnimatedPress(onTap: onTap, child: cell),
    );
  }
}

class _FireMarker extends StatefulWidget {
  const _FireMarker();

  @override
  State<_FireMarker> createState() => _FireMarkerState();
}

class _FireMarkerState extends State<_FireMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB000), size: 17);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -2 * _controller.value),
        child: Transform.scale(scale: 0.88 + (_controller.value * 0.22), child: child),
      ),
      child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB000), size: 17),
    );
  }
}

class _ActivityLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const items = [
      (_ActivityLevel.light, '7m'),
      (_ActivityLevel.steady, '20m'),
      (_ActivityLevel.deep, '45m'),
      (_ActivityLevel.fire, '90m+'),
    ];
    return Row(
      children: [
        Text('Intensity', style: TextStyle(color: c.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
        const Spacer(),
        for (final item in items) ...[
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(color: _dayColors(c, item.$1).$1, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 4),
          Text(item.$2, style: TextStyle(color: c.textSecondary, fontSize: 10)),
          const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime day;
  final int minutes;

  const _DayDetail({required this.day, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppSpacing.brLg),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, color: c.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('${_monthLabel(day)} ${day.day}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600))),
          Text(minutes == 0 ? 'No reading logged' : '$minutes min read', style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MonthButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: AnimatedPress(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppSpacing.brMd),
            child: Icon(icon, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.textTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

enum _ActivityLevel { none, trace, light, steady, deep, fire }

_ActivityLevel _activityLevel(int minutes) {
  if (minutes >= 90) return _ActivityLevel.fire;
  if (minutes >= 45) return _ActivityLevel.deep;
  if (minutes >= 20) return _ActivityLevel.steady;
  if (minutes >= 7) return _ActivityLevel.light;
  if (minutes > 0) return _ActivityLevel.trace;
  return _ActivityLevel.none;
}

(Color, Color) _dayColors(KomaColors c, _ActivityLevel level) => switch (level) {
  _ActivityLevel.none => (c.surfaceMuted, c.textTertiary),
  _ActivityLevel.trace => (c.accentMuted.withValues(alpha: 0.45), c.textSecondary),
  _ActivityLevel.light => (const Color(0xFFFFE1A8), const Color(0xFF6D4300)),
  _ActivityLevel.steady => (const Color(0xFFFFB55E), const Color(0xFF542600)),
  _ActivityLevel.deep => (const Color(0xFFFF7138), Colors.white),
  _ActivityLevel.fire => (const Color(0xFFC6381A), Colors.white),
};

DateTime _dayStart(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _monthStart(DateTime value) => DateTime(value.year, value.month);

String _monthLabel(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
