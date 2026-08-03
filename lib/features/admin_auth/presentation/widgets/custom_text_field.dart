import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E3A8A); // Slate Blue

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(prefixIcon, color: primaryColor.withValues(alpha: 0.7), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
