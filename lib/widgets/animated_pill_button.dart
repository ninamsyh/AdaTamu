import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedPillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color backgroundColor;
  final bool compact;

  const AnimatedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor = AppColors.buttonFormBackground,
    this.compact = false,
  });

  @override
  State<AnimatedPillButton> createState() => _AnimatedPillButtonState();
}

class _AnimatedPillButtonState extends State<AnimatedPillButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 20 : 28,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: disabled
                ? widget.backgroundColor.withOpacity(0.6)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: widget.compact ? 16 : 20,
                  height: widget.compact ? 16 : 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.buttonText,
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon,
                            size: widget.compact ? 16 : 18,
                            color: AppColors.buttonText),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        maxLines: 1,
                        style: widget.compact
                            ? AppTextStyles.buttonLabel.copyWith(fontSize: 14)
                            : AppTextStyles.buttonLabel,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
