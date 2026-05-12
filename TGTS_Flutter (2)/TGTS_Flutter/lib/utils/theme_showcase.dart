import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme.dart';

/// A visual showcase of the app theme
/// Use this widget in development to preview all theme elements
class ThemeShowcase extends StatelessWidget {
  const ThemeShowcase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Showcase'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Color Palette',
            Column(
              children: [
                _buildColorTile('Primary (Saffron)', colorScheme.primary, colorScheme.onPrimary),
                _buildColorTile('Secondary (Green)', colorScheme.secondary, colorScheme.onSecondary),
                _buildColorTile('Tertiary (Navy)', colorScheme.tertiary, colorScheme.onTertiary),
                _buildColorTile('Background', colorScheme.surface, colorScheme.onSurface),
                _buildColorTile('Surface', colorScheme.surface, colorScheme.onSurface),
                _buildColorTile('Error', colorScheme.error, colorScheme.onError),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Typography',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display Large', style: theme.textTheme.displayLarge),
                Text('Display Medium', style: theme.textTheme.displayMedium),
                Text('Display Small', style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('Headline Large', style: theme.textTheme.headlineLarge),
                Text('Headline Medium', style: theme.textTheme.headlineMedium),
                Text('Headline Small', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Title Large', style: theme.textTheme.titleLarge),
                Text('Title Medium', style: theme.textTheme.titleMedium),
                Text('Title Small', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('Body Large', style: theme.textTheme.bodyLarge),
                Text('Body Medium', style: theme.textTheme.bodyMedium),
                Text('Body Small', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Label Large', style: theme.textTheme.labelLarge),
                Text('Label Medium', style: theme.textTheme.labelMedium),
                Text('Label Small', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Buttons',
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Elevated Button'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Outlined Button'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Text Button'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Elevated Button with Icon'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Cards',
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Card Title', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Card content with body text', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Input Fields',
            Column(
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Label',
                    hintText: 'Hint text',
                  ),
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Label',
                    hintText: 'Hint text',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Gradients',
            Column(
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: const Center(
                    child: Text(
                      'Primary Gradient',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.secondaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: const Center(
                    child: Text(
                      'Secondary Gradient',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.indianFlagGradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: const Center(
                    child: Text(
                      'Indian Flag Gradient',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Chips',
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: const Text('Chip'),
                  onDeleted: () {},
                ),
                Chip(
                  label: const Text('Chip with Avatar'),
                  avatar: const CircleAvatar(
                    child: Text('A'),
                  ),
                ),
                ActionChip(
                  label: const Text('Action Chip'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Border Radius Examples',
            Column(
              children: [
                _buildRadiusExample('Small (6px)', AppTheme.radiusSm),
                const SizedBox(height: 8),
                _buildRadiusExample('Medium (8px)', AppTheme.radiusMd),
                const SizedBox(height: 8),
                _buildRadiusExample('Large (10px)', AppTheme.radiusLg),
                const SizedBox(height: 8),
                _buildRadiusExample('Extra Large (14px)', AppTheme.radiusXl),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildColorTile(String label, Color color, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusExample(String label, double radius) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

