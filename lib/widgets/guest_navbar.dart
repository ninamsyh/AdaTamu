import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/guest_code.dart';
import 'adatamu_logo.dart';
import 'mini_calendar_dialog.dart';

class GuestNavbar extends StatefulWidget implements PreferredSizeWidget {
  final String kodeTamu;

  const GuestNavbar({super.key, required this.kodeTamu});

  @override
  State<GuestNavbar> createState() => _GuestNavbarState();

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class _GuestNavbarState extends State<GuestNavbar> {
  DateTime? _previewDate;

  String get _displayedKodeTamu => _previewDate == null
      ? widget.kodeTamu
      : GuestCode.generate(_previewDate!, 1);

  Future<void> _openCalendar() async {
    final DateTime? picked = await showMiniCalendarDialog(
      context,
      initialDate: _previewDate ?? DateTime.now(),
    );
    if (picked == null || !mounted) return;

    final DateTime now = DateTime.now();
    final bool isToday = picked.year == now.year &&
        picked.month == now.month &&
        picked.day == now.day;
    setState(() => _previewDate = isToday ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: AdaTamuLogo(scale: 0.55)),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                        child: _GuestCodeBubble(kodeTamu: _displayedKodeTamu)),
                    const SizedBox(width: 10),
                    _CalendarIconButton(onTap: _openCalendar),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestCodeBubble extends StatelessWidget {
  final String kodeTamu;
  const _GuestCodeBubble({required this.kodeTamu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kodeTamu,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CalendarIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child:
              Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
