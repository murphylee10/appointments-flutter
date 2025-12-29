import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const Sidebar({
    required this.selectedIndex,
    required this.onItemTapped,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      color: AppColors.backgroundCard,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          _buildNavItem(
            context: context,
            icon: Icons.people,
            label: 'Patients',
            index: 0,
            isSelected: selectedIndex == 0,
            colorScheme: colorScheme,
          ),
          SizedBox(height: AppSpacing.sm),
          _buildNavItem(
            context: context,
            icon: Icons.calendar_today,
            label: 'Appointments',
            index: 1,
            isSelected: selectedIndex == 1,
            colorScheme: colorScheme,
          ),
          SizedBox(height: AppSpacing.sm),
          _buildNavItem(
            context: context,
            icon: Icons.insights,
            label: 'Metrics',
            index: 2,
            isSelected: selectedIndex == 2,
            colorScheme: colorScheme,
          ),
          SizedBox(height: AppSpacing.sm),
          _buildNavItem(
            context: context,
            icon: Icons.settings,
            label: 'Settings',
            index: 3,
            isSelected: selectedIndex == 3,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? Border(
                left: BorderSide(
                  color: colorScheme.primary,
                  width: 4,
                ),
              )
            : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? colorScheme.primary : AppColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? colorScheme.primary : AppColors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedTileColor: colorScheme.primary.withOpacity(0.08),
        hoverColor: colorScheme.primary.withOpacity(0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        onTap: () => onItemTapped(index),
      ),
    );
  }
}
