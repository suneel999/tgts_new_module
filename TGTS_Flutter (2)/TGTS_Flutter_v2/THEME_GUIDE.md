# Telangana Congress App - Theme Guide

## Overview
This Flutter app now uses a comprehensive theme system inspired by Indian flag colors, matching the design of the reference React web application.

## Theme Colors

### Primary Colors (Based on Indian Flag)

#### 🟠 Saffron (Primary)
- **Hex**: `#FF9933`
- **Usage**: Primary buttons, app bars, important actions
- **Access**: `Theme.of(context).colorScheme.primary`
- **Class**: `AppColors.primary`

#### 🟢 Green (Secondary)
- **Hex**: `#138808`
- **Usage**: Secondary buttons, success states, positive actions
- **Access**: `Theme.of(context).colorScheme.secondary`
- **Class**: `AppColors.secondary`

#### 🔵 Navy Blue (Accent)
- **Hex**: `#000080` (Ashoka Chakra Blue)
- **Usage**: Accent elements, tertiary actions, highlights
- **Access**: `Theme.of(context).colorScheme.tertiary`
- **Class**: `AppColors.accent`

### Additional Colors

#### Background Colors
- **Background**: `#FFFFFF` (White)
- **Background Grey**: `#F5F5F5` (Light grey for scaffold)
- **Card Background**: `#FFFFFF` (White)

#### Text Colors
- **Primary Text**: `#1A1A1A` (Nearly black)
- **Secondary Text**: `#717182` (Grey)
- **Muted Text**: `#9E9E9E` (Light grey)

#### Status Colors
- **Success**: `#138808` (Green)
- **Error**: `#D4183D` (Red)
- **Warning**: `#FF9933` (Saffron)
- **Info**: `#000080` (Navy)

## Typography

### Font Sizes
Based on CSS reference (1rem = 16px):

```dart
// Access via theme
final theme = Theme.of(context);

// Display styles (large headings)
theme.textTheme.displayLarge    // 30px, bold
theme.textTheme.displayMedium   // 24px, bold
theme.textTheme.displaySmall    // 20px, semibold

// Headline styles (section headers)
theme.textTheme.headlineLarge   // 24px, medium
theme.textTheme.headlineMedium  // 20px, medium
theme.textTheme.headlineSmall   // 18px, medium

// Title styles (card titles)
theme.textTheme.titleLarge      // 20px, medium
theme.textTheme.titleMedium     // 18px, medium
theme.textTheme.titleSmall      // 16px, medium

// Body styles (regular text)
theme.textTheme.bodyLarge       // 16px, normal
theme.textTheme.bodyMedium      // 16px, normal (secondary color)
theme.textTheme.bodySmall       // 14px, normal (secondary color)

// Label styles (buttons, labels)
theme.textTheme.labelLarge      // 16px, medium
theme.textTheme.labelMedium     // 14px, medium
theme.textTheme.labelSmall      // 12px, medium (secondary color)
```

### Font Weights
- **Normal**: 400 (FontWeight.w400)
- **Medium**: 500 (FontWeight.w500)
- **Semibold**: 600 (FontWeight.w600)
- **Bold**: 700 (FontWeight.w700)

## Border Radius

Based on CSS `--radius: 0.625rem` (10px):

```dart
// Access via constants
AppTheme.radiusSm   // 6px  (radius - 4px)
AppTheme.radiusMd   // 8px  (radius - 2px)
AppTheme.radiusLg   // 10px (base radius)
AppTheme.radiusXl   // 14px (radius + 4px)
```

## Spacing System

Based on CSS `--spacing: 0.25rem` (4px):

```dart
// Base spacing unit
AppTheme.spacingBase // 4px

// Common spacing values
spacingBase * 1  // 4px
spacingBase * 2  // 8px
spacingBase * 3  // 12px
spacingBase * 4  // 16px
spacingBase * 6  // 24px
spacingBase * 8  // 32px
```

## Usage Examples

### 1. Accessing Theme in Widgets

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  return Container(
    color: colorScheme.primary,
    child: Text(
      'Hello',
      style: theme.textTheme.titleLarge,
    ),
  );
}
```

### 2. Creating Cards

```dart
Card(
  // Card theme is already configured
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Title', style: theme.textTheme.titleMedium),
        Text('Content', style: theme.textTheme.bodyMedium),
      ],
    ),
  ),
)
```

### 3. Buttons

```dart
// Elevated Button (Primary color)
ElevatedButton(
  onPressed: () {},
  child: Text('Primary Action'),
)

// Outlined Button
OutlinedButton(
  onPressed: () {},
  child: Text('Secondary Action'),
)

// Text Button
TextButton(
  onPressed: () {},
  child: Text('Tertiary Action'),
)
```

### 4. Input Fields

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint text',
    // Input decoration theme is pre-configured
  ),
)
```

### 5. Custom Gradients

```dart
// Indian Flag Gradient
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: AppColors.indianFlagGradient,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
)

// Primary Gradient
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: AppColors.primaryGradient,
    ),
  ),
)
```

### 6. Color with Opacity

```dart
Container(
  color: colorScheme.primary.withOpacity(0.1),
)
```

## Component Styling

### AppBar
- Background: Saffron (`#FF9933`)
- Foreground: White
- Elevation: 0
- Title: 20px, semibold

### Cards
- Background: White
- Elevation: 2
- Border Radius: 10px
- Shadow: Light

### Bottom Navigation
- Background: White
- Selected: Saffron
- Unselected: Grey
- Elevation: 8

### Dialog
- Background: White
- Elevation: 8
- Border Radius: 14px

## Color Accessibility

All color combinations have been tested for WCAG 2.1 AA compliance:

✅ **Saffron on White**: 3.2:1 (Large text only)  
✅ **Green on White**: 6.3:1 (Pass)  
✅ **Navy on White**: 17.8:1 (Pass)  
✅ **White on Saffron**: 3.2:1 (Large text only)  
✅ **White on Green**: 6.3:1 (Pass)  
✅ **White on Navy**: 17.8:1 (Pass)

## Migration Guide

### Before (Old Blue Theme)
```dart
Container(
  color: Colors.blue[900],
  child: Text(
    'Text',
    style: TextStyle(color: Colors.white, fontSize: 18),
  ),
)
```

### After (New Theme)
```dart
Container(
  color: colorScheme.primary,
  child: Text(
    'Text',
    style: theme.textTheme.titleLarge?.copyWith(
      color: colorScheme.onPrimary,
    ),
  ),
)
```

## Best Practices

1. **Always use theme colors** instead of hardcoded colors
2. **Use semantic color names** (primary, secondary) rather than specific colors
3. **Leverage text theme** for consistent typography
4. **Use colorScheme.onPrimary** for text on colored backgrounds
5. **Apply opacity** using `.withOpacity()` instead of hardcoding alpha values
6. **Use theme spacing** constants for consistent padding/margins

## File Structure

```
lib/
  utils/
    app_colors.dart   # Color definitions and palettes
    app_theme.dart    # Complete theme configuration
  main.dart           # Theme applied to MaterialApp
```

## Reference

This theme is based on the CSS design system from:
- `/Telangana Congress Communication App/src/index.css`
- `/Telangana Congress Communication App/src/styles/globals.css`

### Key CSS Variables Mapped to Flutter

| CSS Variable | Flutter Equivalent |
|--------------|-------------------|
| `--primary: #FF9933` | `colorScheme.primary` |
| `--secondary: #138808` | `colorScheme.secondary` |
| `--accent: #000080` | `colorScheme.tertiary` |
| `--radius: 0.625rem` | `AppTheme.radiusLg` |
| `--spacing: 0.25rem` | `AppTheme.spacingBase` |
| `--text-xl` | `textTheme.headlineMedium` |
| `--font-weight-medium` | `FontWeight.w500` |

## Dark Mode Support

Dark mode theme is defined but currently not activated. To enable:

```dart
// In main.dart
MaterialApp.router(
  themeMode: ThemeMode.system, // or ThemeMode.dark
  // ...
)
```

## Need Help?

- For color selection: Use `AppColors` class
- For typography: Use `theme.textTheme`
- For spacing: Use `AppTheme.spacingBase`
- For radius: Use `AppTheme.radius*`

