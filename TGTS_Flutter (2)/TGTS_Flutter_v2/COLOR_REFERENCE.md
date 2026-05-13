# 🎨 Color Reference Card

## Quick Reference

### Primary Colors (Indian Flag)

```
┌─────────────────────────────────────────────────┐
│  🟠 SAFFRON (Primary)                           │
│  #FF9933                                        │
│  Usage: Buttons, AppBar, Important Actions     │
│  Code: AppColors.primary                        │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  ⬜ WHITE (Background)                          │
│  #FFFFFF                                        │
│  Usage: Cards, Backgrounds                     │
│  Code: AppColors.background                     │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  🟢 GREEN (Secondary)                           │
│  #138808                                        │
│  Usage: Success, Secondary Actions             │
│  Code: AppColors.secondary                      │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  🔵 NAVY BLUE (Accent)                          │
│  #000080                                        │
│  Usage: Accent Elements, Tertiary Actions      │
│  Code: AppColors.accent                         │
└─────────────────────────────────────────────────┘
```

## Color Palette Overview

### Saffron Family (Primary)
```dart
AppColors.primary       // #FF9933 (Main)
AppColors.primaryLight  // #FFB366 (Light variant)
AppColors.primaryDark   // #FF6600 (Dark variant)
```

### Green Family (Secondary)
```dart
AppColors.secondary       // #138808 (Main)
AppColors.secondaryLight  // #2E7D32 (Light variant)
AppColors.secondaryDark   // #0A5C05 (Dark variant)
```

### Navy Family (Accent)
```dart
AppColors.accent       // #000080 (Main)
AppColors.accentLight  // #0000B3 (Light variant)
AppColors.accentDark   // #000066 (Dark variant)
```

## Usage Guide

### When to Use Each Color

#### 🟠 Saffron (Primary)
- ✅ Primary action buttons
- ✅ App bars and headers
- ✅ Important notifications
- ✅ Active navigation items
- ✅ Primary icons
- ❌ Body text (use sparingly)
- ❌ Backgrounds (too bright)

#### 🟢 Green (Secondary)
- ✅ Success messages
- ✅ Positive actions (approve, confirm)
- ✅ Growth indicators
- ✅ Active status
- ✅ Secondary buttons
- ❌ Error states
- ❌ Warning messages

#### 🔵 Navy (Accent)
- ✅ Accent elements
- ✅ Tertiary buttons
- ✅ Information messages
- ✅ Links (use sparingly)
- ✅ Alternative icons
- ❌ Primary actions
- ❌ Large backgrounds (too dark)

## Color Combinations

### Best Combinations ✅

```
Saffron + White
  Background: Saffron (#FF9933)
  Text: White (#FFFFFF)
  Contrast: 3.2:1 (Large text only)

Green + White
  Background: Green (#138808)
  Text: White (#FFFFFF)
  Contrast: 6.3:1 ✓ WCAG AA Pass

Navy + White
  Background: Navy (#000080)
  Text: White (#FFFFFF)
  Contrast: 17.8:1 ✓ WCAG AAA Pass

White + Saffron
  Background: White (#FFFFFF)
  Text: Saffron (#FF9933)
  Contrast: 3.2:1 (Large text only)

White + Green
  Background: White (#FFFFFF)
  Text: Green (#138808)
  Contrast: 6.3:1 ✓ WCAG AA Pass

White + Navy
  Background: White (#FFFFFF)
  Text: Navy (#000080)
  Contrast: 17.8:1 ✓ WCAG AAA Pass
```

### Avoid These ❌

```
Saffron + Green      (Poor contrast)
Saffron + Navy       (Too vibrant)
Green + Navy         (Too dark)
Saffron + Black      (Too harsh)
```

## Gradients

### Primary Gradient (Saffron)
```dart
AppColors.primaryGradient
Colors: [#FF9933, #FF8000, #FF6600]
```

### Secondary Gradient (Green)
```dart
AppColors.secondaryGradient
Colors: [#138808, #2E7D32]
```

### Indian Flag Gradient
```dart
AppColors.indianFlagGradient
Colors: [#FF9933, #FFFFFF, #138808]
Direction: Top to Bottom
```

## Text Colors

```dart
AppColors.textPrimary     // #1A1A1A (Almost black)
AppColors.textSecondary   // #717182 (Grey)
AppColors.textMuted       // #9E9E9E (Light grey)
AppColors.textOnPrimary   // #FFFFFF (White)
AppColors.textOnSecondary // #FFFFFF (White)
AppColors.textOnAccent    // #FFFFFF (White)
```

### Text Color Usage

| Background Color | Text Color to Use |
|------------------|-------------------|
| Saffron | `textOnPrimary` (White) |
| Green | `textOnSecondary` (White) |
| Navy | `textOnAccent` (White) |
| White | `textPrimary` (Dark) |
| Light Grey | `textPrimary` (Dark) |
| Cards | `textPrimary` or `textSecondary` |

## Status Colors

```dart
// Success (matches Green)
AppColors.success = #138808
Use: Success messages, completed states

// Error
AppColors.error = #D4183D
Use: Error messages, failed states

// Warning (matches Saffron)
AppColors.warning = #FF9933
Use: Warning messages, caution states

// Info (matches Navy)
AppColors.info = #000080
Use: Information messages, neutral states
```

## Chart Colors

For data visualization:

```dart
AppColors.chart1 = #FF9933 (Saffron)
AppColors.chart2 = #138808 (Green)
AppColors.chart3 = #000080 (Navy)
AppColors.chart4 = #FF6600 (Orange)
AppColors.chart5 = #2E7D32 (Dark Green)
```

## UI Element Colors

```dart
// Borders & Dividers
AppColors.border  = rgba(0, 0, 0, 0.1)
AppColors.divider = #E0E0E0

// Backgrounds
AppColors.background      = #FFFFFF
AppColors.backgroundGrey  = #F5F5F5
AppColors.cardBackground  = #FFFFFF
AppColors.inputBackground = #F3F3F5

// Muted Elements
AppColors.muted           = #ECECF0
AppColors.mutedForeground = #717182
```

## Opacity Guide

```dart
// For overlays and subtle backgrounds
primary.withOpacity(0.05)  // Very subtle hint
primary.withOpacity(0.10)  // Light background
primary.withOpacity(0.20)  // Subtle background
primary.withOpacity(0.30)  // Visible background
primary.withOpacity(0.50)  // Medium transparency
primary.withOpacity(0.80)  // Mostly opaque
```

## Shadow Colors

```dart
AppColors.shadowLight  = rgba(0, 0, 0, 0.1)  // Subtle shadows
AppColors.shadowMedium = rgba(0, 0, 0, 0.2)  // Normal shadows
AppColors.shadowDark   = rgba(0, 0, 0, 0.3)  // Strong shadows
```

## Examples in Code

### Button with Primary Color
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
  ),
  onPressed: () {},
  child: const Text('Primary Action'),
)
```

### Card with Gradient
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: AppColors.primaryGradient,
    ),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      'Gradient Card',
      style: TextStyle(color: AppColors.textOnPrimary),
    ),
  ),
)
```

### Status Badge
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.success,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    'Success',
    style: TextStyle(
      color: AppColors.textOnSecondary,
      fontWeight: FontWeight.bold,
    ),
  ),
)
```

## Design Tips

1. **Use Primary (Saffron) sparingly** - It's bright and should be used for important elements
2. **Green for positive actions** - Confirm, approve, success states
3. **Navy for information** - Less aggressive than primary, good for tertiary actions
4. **White space is key** - Use `backgroundGrey` for better visual hierarchy
5. **Consistent opacity** - Use standard opacity values (0.1, 0.2, 0.3, etc.)
6. **Test contrast** - Always check text readability on colored backgrounds

## Color Accessibility

| Combination | Contrast Ratio | WCAG Level | Best For |
|-------------|----------------|------------|----------|
| Saffron/White | 3.2:1 | Large text | Headings, buttons |
| Green/White | 6.3:1 | AA | Body text, buttons |
| Navy/White | 17.8:1 | AAA | Any text |
| Black/White | 21:1 | AAA | Any text |

## Print Reference

**Primary**: #FF9933 (RGB: 255, 153, 51)  
**Secondary**: #138808 (RGB: 19, 136, 8)  
**Accent**: #000080 (RGB: 0, 0, 128)  

---

**Quick Tip**: Keep this file handy when designing new screens!

