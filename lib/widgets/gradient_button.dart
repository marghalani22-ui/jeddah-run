import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Main call-to-action: sunset gradient, white bold label, 56px tall.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.icon, required this.onPressed, this.gradient = Grad.sunset, this.height = 56, this.busy = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(Radii.btn + 4),
          boxShadow: enabled ? const [BoxShadow(color: Color(0x40F25C2C), blurRadius: 18, offset: Offset(0, 8))] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.btn + 4),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                else if (icon != null)
                  Icon(icon, color: Colors.white, size: 22),
                if (busy || icon != null) const SizedBox(width: 10),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
