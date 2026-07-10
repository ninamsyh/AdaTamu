import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Future<DateTime?> showMiniCalendarDialog(
  BuildContext context, {
  DateTime? initialDate,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (context) => _MiniCalendarDialogContent(
      initialDate: initialDate ?? DateTime.now(),
    ),
  );
}

class _MiniCalendarDialogContent extends StatefulWidget {
  final DateTime initialDate;

  const _MiniCalendarDialogContent({required this.initialDate});

  @override
  State<_MiniCalendarDialogContent> createState() =>
      _MiniCalendarDialogContentState();
}

class _MiniCalendarDialogContentState
    extends State<_MiniCalendarDialogContent> {
  late DateTime _selectedDate = widget.initialDate;
  late DateTime _displayedMonth =
      DateTime(_selectedDate.year, _selectedDate.month);

  static const List<String> _namaBulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _namaHariLengkap = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _namaHariGrid = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  String get _formattedSelectedDate {
    final String namaHari = _namaHariLengkap[_selectedDate.weekday - 1];
    return '$namaHari, ${_selectedDate.day} ${_namaBulan[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _changeMonthBy(int delta) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    });
  }

  void _jumpToMonth(int month) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, month);
    });
  }

  void _jumpToYear(int year) {
    setState(() {
      _displayedMonth = DateTime(year, _displayedMonth.month);
    });
  }

  void _selectDay(int day) {
    setState(() {
      _selectedDate =
          DateTime(_displayedMonth.year, _displayedMonth.month, day);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = now;
      _displayedMonth = DateTime(now.year, now.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final int firstYear = now.year - 100;
    final int lastYear = now.year + 100;

    final int daysInMonth =
        _daysInMonth(_displayedMonth.year, _displayedMonth.month);

    final int firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final int leadingEmptyCells = firstWeekday - 1;

    final bool isDisplayingCurrentMonth =
        _displayedMonth.year == now.year && _displayedMonth.month == now.month;
    final bool isSelectionInDisplayedMonth =
        _selectedDate.year == _displayedMonth.year &&
            _selectedDate.month == _displayedMonth.month;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppColors.inputBorderFocused, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Kalender',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.labelText,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderFocused.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formattedSelectedDate,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.inputBorderFocused,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: _goToToday,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: BorderSide(
                          color: AppColors.inputBorderFocused.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Hari ini',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.inputBorderFocused,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DropdownPill<int>(
                      value: _displayedMonth.month,
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(
                            _namaBulan[i],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      onChanged: (month) {
                        if (month != null) _jumpToMonth(month);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DropdownPill<int>(
                      value: _displayedMonth.year,
                      items: [
                        for (int y = lastYear; y >= firstYear; y--)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (year) {
                        if (year != null) _jumpToYear(year);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: AppColors.inputBorderFocused,
                    onPressed: () => _changeMonthBy(-1),
                  ),
                  Text(
                    '${_namaBulan[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.labelText,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: AppColors.inputBorderFocused,
                    onPressed: () => _changeMonthBy(1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: _namaHariGrid
                    .map(
                      (h) => Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              h,
                              style: TextStyle(
                                fontFamily: AppTextStyles.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: leadingEmptyCells + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingEmptyCells) {
                    return const SizedBox.shrink();
                  }

                  final int day = index - leadingEmptyCells + 1;
                  final bool isToday =
                      isDisplayingCurrentMonth && day == now.day;
                  final bool isSelected =
                      isSelectionInDisplayedMonth && day == _selectedDate.day;

                  return GestureDetector(
                    onTap: () => _selectDay(day),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.inputBorderFocused
                            : isToday
                                ? AppColors.inputBorderFocused.withOpacity(0.12)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppColors.inputBorderFocused
                                  : AppColors.labelText,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0E0E0),
                          foregroundColor: AppColors.labelText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.inputBorderFocused,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(_selectedDate);
                        },
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownPill({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.inputBorderFocused.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.inputBorderFocused.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.labelText,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
