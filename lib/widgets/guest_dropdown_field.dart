import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GuestDropdownField extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const GuestDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<GuestDropdownField> createState() => GuestDropdownFieldState();
}

class GuestDropdownFieldState extends State<GuestDropdownField> {
  String? _errorText;
  bool validate() {
    if (widget.value == null) {
      setState(() => _errorText = 'Jenis kelamin tidak boleh kosong');
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  void _clearError() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
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
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: hasError ? Colors.red : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: PopupMenuButton<String>(
            // Posisi menu selalu di bawah tombol/anchor.
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            constraints: const BoxConstraints(minWidth: double.infinity),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: AppColors.inputFill,
            onSelected: (selected) {
              _clearError();
              widget.onChanged(selected);
            },
            itemBuilder: (context) => widget.options
                .map(
                  (opt) => PopupMenuItem<String>(
                    value: opt,
                    child: Center(
                      child: Text(opt,
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 14,
                          )),
                    ),
                  ),
                )
                .toList(),
            // Tampilan field (anchor) bergaya pil putih.
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Teks rata tengah; ikon diletakkan di kanan.
                  Expanded(
                    child: Text(
                      widget.value ?? 'Pilih',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 14,
                        color: widget.value == null
                            ? Colors.black54
                            : Colors.black,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
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
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
