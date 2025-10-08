# Subscription Badge Design Guide

## Badge Appearance

### Weekly Subscription Badge
```
┌─────────────────────────┐
│  🗓️ Weekly             │  ← Purple gradient (#667eea → #764ba2)
└─────────────────────────┘
```
- **Icon**: Calendar week view (⬜️⬜️⬜️⬜️⬜️⬜️⬜️)
- **Colors**: Purple gradient
- **Use case**: Subscriptions that renew every 7 days

### Monthly Subscription Badge
```
┌─────────────────────────┐
│  📅 Monthly            │  ← Pink gradient (#f093fb → #f5576c)
└─────────────────────────┘
```
- **Icon**: Calendar month view (📅)
- **Colors**: Pink/Rose gradient
- **Use case**: Subscriptions that renew every 30 days (most common)

### Yearly Subscription Badge
```
┌─────────────────────────┐
│  📆 Yearly             │  ← Blue gradient (#4facfe → #00f2fe)
└─────────────────────────┘
```
- **Icon**: Calendar (📆)
- **Colors**: Blue/Cyan gradient
- **Use case**: Subscriptions that renew annually

## Card Layout Examples

### Subscription Card (List View)
```
┌───────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════╗ │ ← Purple border (2px)
│ ║ [Receipt Image]  Netflix                  🗓️ Weekly  ║ │ ← Badge in top-right
│ ║      80x100       Oct 07, 2025                        ║ │
│ ║                   78.00 USD                           ║ │
│ ║                   [Entertainment]                     ║ │
│ ╚═══════════════════════════════════════════════════════╝ │
└───────────────────────────────────────────────────────────┘
```

### Regular Expense Card (for comparison)
```
┌───────────────────────────────────────────────────────────┐
│ ┌─────────────────────────────────────────────────────────┐ │ ← No special border
│ │ [Receipt Image]  Grocery Store                          │ │ ← No badge
│ │      80x100       Oct 07, 2025                          │ │
│ │                   67.00 USD                             │ │
│ │                   [Food & Dining]                       │ │
│ └─────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

## Color Palette

### Weekly (Purple)
- Primary: `#667eea` (Soft Purple)
- Secondary: `#764ba2` (Deep Purple)
- Border: `#667eea` with 30% opacity
- Shadow: `#667eea` with 10-40% opacity

### Monthly (Pink/Rose)
- Primary: `#f093fb` (Bright Pink)
- Secondary: `#f5576c` (Rose Red)
- Border: `#f093fb` with 30% opacity
- Shadow: `#f093fb` with 10-40% opacity

### Yearly (Blue/Cyan)
- Primary: `#4facfe` (Sky Blue)
- Secondary: `#00f2fe` (Bright Cyan)
- Border: `#4facfe` with 30% opacity
- Shadow: `#4facfe` with 10-40% opacity

## Badge Sizes

### Standard (List View)
- Icon: 14px
- Text: ~10px (0.7x icon size)
- Padding: 8px horizontal, 4px vertical
- Border radius: 12px

### Compact (Calendar View)
- Icon: 12px
- Text: ~8px
- Padding: 6px horizontal, 3px vertical
- Border radius: 8px

## Badge Positioning

### List View Cards
```
┌─────────────────────────────────────┐
│                           [Badge]   │ ← Top-right corner (8px from edges)
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### Calendar View Cards
```
┌───────────────────┐
│          [Badge]  │ ← Top-right corner (8px from edges)
│                   │
│                   │
└───────────────────┘
```

## Shadow & Border Effects

### Card Border
- **Width**: 2px
- **Color**: Subscription type color with 30% opacity
- **Purpose**: Subtle frame to draw attention without being overwhelming

### Card Shadow
- **Blur**: 8px
- **Offset**: (0, 4)
- **Color**: Subscription type color with 10% opacity
- **Purpose**: Adds depth and makes subscription cards stand out slightly

### Badge Shadow
- **Blur**: 4px
- **Offset**: (0, 2)
- **Color**: Badge primary color with 30% opacity
- **Purpose**: Makes badge pop from the card surface

## Animation Ideas (Future Enhancement)

### Badge Pulse
```dart
// Subtle animation to draw attention to new subscriptions
Animation<double> _animation = Tween<double>(
  begin: 1.0,
  end: 1.05,
).animate(CurvedAnimation(
  parent: controller,
  curve: Curves.easeInOut,
));
```

### Border Glow
- Animate border opacity from 30% to 50% and back
- Duration: 2 seconds
- Makes newly added subscriptions stand out

## Accessibility Considerations

1. **Color + Text**: Badges use both color and text to convey information
2. **Icons**: Universal calendar icons aid recognition
3. **Border**: Additional visual cue beyond just color
4. **Contrast**: All badge colors have sufficient contrast with white text
5. **Size**: Badge text is large enough to be readable (minimum 10px)

## Best Practices

### DO:
- ✅ Keep badges in consistent position (top-right)
- ✅ Use clear, short labels ("Weekly", "Monthly", "Yearly")
- ✅ Maintain color consistency across the app
- ✅ Make badges non-interactive (informational only)

### DON'T:
- ❌ Cover important information with badges
- ❌ Use similar colors for different subscription types
- ❌ Make badges too large or distracting
- ❌ Add too many visual effects that slow performance

## Implementation Tips

1. **Conditional Rendering**: Only show SubscriptionCardDecoration when `subscriptionType != null`
2. **Null Safety**: Always check for null before displaying badges
3. **Performance**: Use `const` constructors where possible
4. **Consistency**: Apply the same decoration in all views (list, calendar, details)

## Comparison Summary

| Feature | Regular Receipt | Manual Expense | Subscription |
|---------|----------------|----------------|--------------|
| Border | Standard | Standard | **Colored** |
| Badge | None | None | **Yes (with type)** |
| Shadow | Standard | Standard | **Enhanced** |
| Visual Weight | Normal | Normal | **Emphasized** |

## User Testing Feedback Points

When testing with users, gather feedback on:
1. Can users easily identify subscriptions at a glance?
2. Do the colors make sense for the subscription types?
3. Are the badges too prominent or too subtle?
4. Does the badge position interfere with any interactions?
5. Do users find the visual indicators helpful?

---

**Note**: This design is intentionally eye-catching but not overwhelming, striking a balance between visibility and maintaining a clean, professional UI.
