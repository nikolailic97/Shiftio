import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';

class ShiftioTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const ShiftioTimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
  });

  @override
  State<ShiftioTimePicker> createState() => _ShiftioTimePickerState();
}

class _ShiftioTimePickerState extends State<ShiftioTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.onTimeChanged(
      TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? AppColors.inputFillDark : AppColors.inputFillLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selekcijska linija
          Positioned(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sati
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedHour = index);
                    _onChanged();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 24,
                    builder: (context, index) {
                      return _WheelItem(
                        label: index.toString().padLeft(2, '0'),
                        isSelected: index == _selectedHour,
                      );
                    },
                  ),
                ),
              ),

              // Separator
              Text(
                ':',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),

              // Minuti
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedMinute = index);
                    _onChanged();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 60,
                    builder: (context, index) {
                      return _WheelItem(
                        label: index.toString().padLeft(2, '0'),
                        isSelected: index == _selectedMinute,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Duration Picker Widget ───────────────────────────────────────────────────
class ShiftioDurationPicker extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final ValueChanged<int> onDurationChanged; // vraca ukupne minute

  const ShiftioDurationPicker({
    super.key,
    required this.initialHours,
    required this.initialMinutes,
    required this.onDurationChanged,
  });

  @override
  State<ShiftioDurationPicker> createState() => _ShiftioDurationPickerState();
}

class _ShiftioDurationPickerState extends State<ShiftioDurationPicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHours;
  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedHours = widget.initialHours;
    _selectedMinutes = widget.initialMinutes;
    _hourController = FixedExtentScrollController(initialItem: _selectedHours);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinutes);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.onDurationChanged(_selectedHours * 60 + _selectedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? AppColors.inputFillDark : AppColors.inputFillLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sati
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedHours = index);
                    _onChanged();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 24,
                    builder: (context, index) {
                      return _WheelItem(
                        label: '${index}h',
                        isSelected: index == _selectedHours,
                      );
                    },
                  ),
                ),
              ),

              // Minuti
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 44,
                  perspective: 0.003,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedMinutes = index);
                    _onChanged();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 60,
                    builder: (context, index) {
                      return _WheelItem(
                        label: '${index}min',
                        isSelected: index == _selectedMinutes,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Wheel Item ───────────────────────────────────────────────────────────────
class _WheelItem extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _WheelItem({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: isSelected ? 22 : 16,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
          color: isSelected
              ? AppColors.primary
              : (isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight),
        ),
      ),
    );
  }
}
