import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class DayPickerWidget extends StatefulWidget {
  final DateTime selectedDate;
  final Set<int> daysWithShifts;
  final ValueChanged<DateTime> onDateSelected;

  const DayPickerWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.daysWithShifts = const {},
  });

  @override
  State<DayPickerWidget> createState() => _DayPickerWidgetState();
}

class _DayPickerWidgetState extends State<DayPickerWidget> {
  static const int _initialPage = 1200;
  late PageController _pageController;
  late int _currentPage;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final selected = widget.selectedDate;
    // Broj mjeseci od now do selected
    final diff = (selected.year - now.year) * 12 + (selected.month - now.month);
    _currentPage = _initialPage + diff;
    _currentMonth = DateTime(selected.year, selected.month);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final now = DateTime.now();
    final diff = page - _initialPage;
    return DateTime(now.year, now.month + diff);
  }

  void _prevMonth() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _nextMonth() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // ─── Month Header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                onPressed: _prevMonth,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _formatMonth(_currentMonth),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 26),
                onPressed: _nextMonth,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        // ─── Days of Week ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (d == 'Sub' || d == 'Ned')
                                ? AppColors.error.withOpacity(0.7)
                                : isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 4),

        // ─── Calendar Grid ────────────────────────────────────────────────
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
                _currentMonth = _monthForPage(page);
              });
            },
            itemBuilder: (_, page) {
              final month = _monthForPage(page);
              return _MonthGrid(
                month: month,
                selectedDate: widget.selectedDate,
                daysWithShifts: widget.daysWithShifts,
                onDateSelected: widget.onDateSelected,
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Jun',
      'Jul',
      'Avgust',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Set<int> daysWithShifts;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.daysWithShifts,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.1,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: startOffset + daysInMonth,
        itemBuilder: (_, index) {
          if (index < startOffset) return const SizedBox.shrink();

          final dayNum = index - startOffset + 1;
          final date = DateTime(month.year, month.month, dayNum);

          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;

          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          final hasShift = daysWithShifts.contains(dayNum);
          final isWeekend = date.weekday >= 6;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected
                    ? Border.all(
                        color: AppColors.primary.withOpacity(0.5), width: 1.5)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isWeekend
                              ? AppColors.error.withOpacity(0.8)
                              : isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                    ),
                  ),
                  if (hasShift)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 7),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
