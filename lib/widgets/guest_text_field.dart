import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GuestTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const GuestTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
  });

  @override
  State<GuestTextField> createState() => _GuestTextFieldState();
}

class _GuestTextFieldState extends State<GuestTextField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_clearErrorOnType);
  }

  void _clearErrorOnType() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_clearErrorOnType);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = _errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(widget.label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(widget.maxLines > 1 ? 16 : 30),
            border: Border.all(
              color: hasError ? Colors.red : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            textAlign: widget.maxLines > 1 ? TextAlign.start : TextAlign.center,
            style: const TextStyle(fontSize: 13),
            validator: (value) {
              final result = widget.validator?.call(value);
              // Tunda setState agar tidak bentrok dengan proses build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _errorText != result) {
                  setState(() => _errorText = result);
                }
              });
              return result;
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: InputBorder.none,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 26,
          width: double.infinity,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
