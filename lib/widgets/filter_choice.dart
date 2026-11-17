import 'package:flutter/material.dart';

class FilterChoice extends StatelessWidget {
  const FilterChoice(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected,
      this.icon});

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 15, color: foreground),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      shape: const StadiumBorder(),
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: .78),
      selectedColor: colors.primary,
      side: BorderSide(
          color: selected
              ? Colors.transparent
              : colors.outlineVariant.withValues(alpha: .68)),
      labelStyle: theme.textTheme.labelMedium
          ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
