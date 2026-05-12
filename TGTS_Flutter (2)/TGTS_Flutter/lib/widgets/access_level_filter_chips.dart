import 'package:flutter/material.dart';
import '../utils/lang_ext.dart';
import '../utils/app_colors.dart';
import '../models/index.dart';

/// Reusable widget for displaying access level filter chips
class AccessLevelFilterChips extends StatelessWidget {
  final List<String> availableAccessLevels;
  final String selectedAccessLevel;
  final Function(String) onLevelSelected;

  const AccessLevelFilterChips({
    Key? key,
    required this.availableAccessLevels,
    required this.selectedAccessLevel,
    required this.onLevelSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show filters if no levels are available
    if (availableAccessLevels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppColors.backgroundGrey,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            context.lang == Language.en ? 'Filter by Access Level' : 'ప్రవేశ స్థాయి ద్వారా ఫిల్టర్ చేయండి',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.2, // Reduce line height to prevent overflow
            ),
          ),
          const SizedBox(height: 5), // Reduced from 6 to 5
          Wrap(
            spacing: 6,
            runSpacing: 5, // Reduced from 6 to 5
            clipBehavior: Clip.none,
            children: availableAccessLevels.map((level) {
              final isSelected = selectedAccessLevel == level;
              return FilterChip(
                label: Text(
                  context.lang == Language.en
                      ? level.toUpperCase()
                      : level,
                  style: const TextStyle(fontSize: 11, height: 1.1), // Reduced line height
                ),
                selected: isSelected,
                onSelected: (selected) {
                  onLevelSelected(level);
                },
                backgroundColor: Colors.grey[200],
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Reduced from 2 to 1
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

