import 'package:flutter/material.dart';
import 'dart:io';
import '../core/localization.dart';
import 'package:flutter/services.dart';

// Avoid OverlayPortal-backed controls here: older Flutter Windows engines
// can crash while accessibility tools traverse a changing overlay subtree.
class PlayerControlButton extends StatelessWidget {
  final String tooltip;
  final Widget icon;
  final Color? color;
  final VoidCallback? onPressed;
  const PlayerControlButton(
      {super.key,
      required this.tooltip,
      required this.icon,
      this.color,
      this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        enabled: onPressed != null,
        onTap: onPressed,
        excludeSemantics: true,
        child: IconButton(
          icon: icon,
          color: color,
          onPressed: onPressed,
          style: Platform.isWindows
              ? IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  overlayColor: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),
      );
}

class PlayerSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  const PlayerSlider(
      {super.key,
      required this.value,
      this.label = 'Громкость',
      this.min = 0,
      this.max = 1,
      this.onChanged});

  @override
  State<PlayerSlider> createState() => PlayerSliderState();
}

class PlayerSliderState extends State<PlayerSlider> {
  double? _dragValue;
  bool _focused = false;

  void _change(double value) {
    widget.onChanged?.call(value.clamp(widget.min, widget.max));
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (widget.onChanged == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final step = (widget.max - widget.min) / 100;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _change(widget.value - step);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _change(widget.value + step);
    } else if (key == LogicalKeyboardKey.home) {
      _change(widget.min);
    } else if (key == LogicalKeyboardKey.end) {
      _change(widget.max);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final value = (_dragValue ?? widget.value).clamp(widget.min, widget.max);
    final fraction = (value - widget.min) / (widget.max - widget.min);
    final scheme = Theme.of(context).colorScheme;
    final color =
        enabled ? scheme.primary : scheme.onSurface.withValues(alpha: .3);
    final step = (widget.max - widget.min) / 100;
    return Semantics(
      slider: true,
      label: context.tr(widget.label),
      enabled: enabled,
      value: '${(fraction * 100).round()}%',
      increasedValue: '${((fraction * 100) + 1).clamp(0, 100).round()}%',
      decreasedValue: '${((fraction * 100) - 1).clamp(0, 100).round()}%',
      onIncrease: enabled ? () => _change(value + step) : null,
      onDecrease: enabled ? () => _change(value - step) : null,
      excludeSemantics: true,
      child: Focus(
        canRequestFocus: enabled,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _key,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final trackWidth = (width - 32).clamp(1.0, double.infinity);
          double fromX(double x) =>
              widget.min +
              ((x - 16) / trackWidth).clamp(0.0, 1.0) *
                  (widget.max - widget.min);
          void drag(double x) {
            final value = fromX(x);
            setState(() => _dragValue = value);
            _change(value);
          }

          return MouseRegion(
            cursor:
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: enabled
                  ? (details) => _change(fromX(details.localPosition.dx))
                  : null,
              onHorizontalDragStart:
                  enabled ? (details) => drag(details.localPosition.dx) : null,
              onHorizontalDragUpdate:
                  enabled ? (details) => drag(details.localPosition.dx) : null,
              onHorizontalDragEnd:
                  enabled ? (_) => setState(() => _dragValue = null) : null,
              onHorizontalDragCancel:
                  enabled ? () => setState(() => _dragValue = null) : null,
              child: SizedBox(
                  height: 48,
                  width: width,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(
                        left: 16,
                        right: 16,
                        child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 4,
                            color: color,
                            backgroundColor:
                                scheme.onSurface.withValues(alpha: .2))),
                    Positioned(
                        left: 16 + trackWidth * fraction - 7,
                        child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: _focused
                                    ? Border.all(
                                        color: scheme.onSurface, width: 2)
                                    : null))),
                  ])),
            ),
          );
        }),
      ),
    );
  }
}
