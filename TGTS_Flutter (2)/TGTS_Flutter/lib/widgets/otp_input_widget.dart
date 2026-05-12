import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

class OTPInputWidget extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;

  const OTPInputWidget({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<OTPInputWidget> createState() => _OTPInputWidgetState();
}

class _OTPInputWidgetState extends State<OTPInputWidget> {
  Future<void> _handlePaste() async {
    if (!widget.enabled) return;
    
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clipboardData?.text ?? '';
      final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (digitsOnly.isEmpty) return;

      final code = digitsOnly.length >= widget.length
          ? digitsOnly.substring(0, widget.length)
          : digitsOnly;

      // Fill the OTP fields by calling onChanged
      widget.onChanged(code);
      if (code.length == widget.length) {
        widget.onCompleted?.call(code);
      }
    } catch (e) {
      // Silently handle clipboard errors
      debugPrint('Paste error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // OTP Fields
        OtpTextField(
          numberOfFields: widget.length,
          enabled: widget.enabled,
          autoFocus: false,
          keyboardType: TextInputType.number,
          showFieldAsBox: true,
          mainAxisAlignment: MainAxisAlignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          borderColor: widget.inactiveColor ?? colorScheme.outline,
          focusedBorderColor: widget.activeColor ?? colorScheme.primary,
          disabledBorderColor: (widget.inactiveColor ?? colorScheme.outline).withValues(alpha: 0.3),
          fieldWidth: 50,
          fieldHeight: 50,
          borderRadius: BorderRadius.circular(8),
          borderWidth: 1,
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.0,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: colorScheme.surface,
          cursorColor: widget.activeColor ?? colorScheme.primary,
          onSubmit: (String otp) {
            widget.onChanged(otp);
            widget.onCompleted?.call(otp);
          },
          onCodeChanged: (String value) {
            widget.onChanged(value);
            if (value.length == widget.length) {
              widget.onCompleted?.call(value);
            }
          },
          clearText: false,
        ),
        const SizedBox(height: 16),
        // Paste Button
        TextButton.icon(
          onPressed: widget.enabled ? _handlePaste : null,
          icon: const Icon(Icons.paste, size: 18),
          label: const Text('Paste OTP'),
          style: TextButton.styleFrom(
            foregroundColor: widget.activeColor ?? colorScheme.primary,
          ),
        ),
      ],
    );
  }
}