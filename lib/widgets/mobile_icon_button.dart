import 'package:flutter/material.dart';

class MobileIconButton extends StatefulWidget {
  const MobileIconButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.emphasized = false});

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  State<MobileIconButton> createState() => _MobileIconButtonState();
}

class _MobileIconButtonState extends State<MobileIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        widget.emphasized ? colors.primary : colors.surfaceContainerHighest;
    final foreground = widget.emphasized ? colors.onPrimary : colors.onSurface;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return Tooltip(
      message: widget.label,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            radius: 25,
            child: Center(
                child: AnimatedScale(
              duration: motion,
              curve: Curves.easeOutCubic,
              scale: _pressed ? .88 : 1,
              child: Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: foreground.withValues(alpha: .12))),
                child: Center(
                    child: IconTheme.merge(
                  data: IconThemeData(size: 22, color: foreground),
                  child: widget.icon,
                )),
              ),
            )),
          ),
        ),
      ),
    );
  }
}
