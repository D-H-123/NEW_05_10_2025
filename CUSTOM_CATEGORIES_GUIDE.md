# Custom Categories Feature Guide

## Overview

SmartReceipt now supports **Custom Categories** - a powerful feature that allows users to create personalized expense categories with custom names, emojis/symbols, colors, and keywords for automatic OCR detection.

## Features

### ✨ What You Can Do

1. **Create Custom Categories** - Add your own expense categories beyond the predefined ones
2. **Personalize with Emojis** - Choose from 30+ emojis to represent your category
3. **Custom Colors** - Select from 19 different colors to make categories visually distinct
4. **Smart Keywords** - Add keywords for automatic category detection during OCR scanning
5. **Context-Specific** - Choose where each category appears (Receipt Scanning, Manual Expense, or Subscription)
6. **Full Management** - Edit or delete custom categories anytime

## How to Access

1. Open the app
2. Navigate to **Settings/Profile** (bottom right tab)
3. Scroll to **Personalization** section
4. Tap on **Custom Categories**

## Creating a New Category

### Step-by-Step Guide

1. **Open Custom Categories Page**
   - From Settings → Custom Categories

2. **Tap the "Add Category" Button**
   - Floating action button at the bottom right

3. **Fill in Category Details:**

   - **Category Name** (Required)
     - Enter a descriptive name (e.g., "Pet Expenses", "Gym & Fitness")
     - The name must be unique (no duplicates)
   
   - **Select Symbol/Emoji** (Required)
     - Choose from 30+ emojis
     - Swipe horizontally to see all options
     - Examples: 🐕 for pets, 🏋️ for gym, 📦 for general
   
   - **Select Color** (Required)
     - Choose from 19 vibrant colors
     - Helps visually distinguish categories in charts and lists
   
   - **Available In** (Required - at least one)
     - ✅ **Receipt Scanning** - Show in post-capture receipt editing
     - ✅ **Manual Expense** - Show when manually adding expenses
     - ✅ **Subscription** - Show when adding subscriptions
     - You can select multiple options
   
   - **Keywords** (Optional)
     - Add comma-separated keywords for OCR auto-detection
     - Example: "vet, pet store, petco, pet food"
     - When scanning receipts, if these keywords appear, the category is auto-selected

4. **Save Your Category**
   - Tap "Create Category"
   - Your custom category is now available!

## Using Custom Categories

### In Receipt Scanning (Post-Capture Page)

1. Scan a receipt using the camera
2. On the post-capture editing page, tap the category dropdown
3. Your custom categories appear at the bottom of the list
4. If you added keywords, and they're detected in the OCR text, the category may be pre-selected

### In Manual Expense Entry

1. From Home page, tap "Add Manually"
2. Fill in expense details
3. In the category dropdown, your custom categories appear
4. Select your custom category

### In Subscriptions

1. From Home page, tap "Add Subscription"
2. Fill in subscription details
3. In the category dropdown, your custom categories appear
4. Select your custom category

## Editing Categories

1. Go to Settings → Custom Categories
2. Find the category you want to edit
3. Tap the **Edit** (pencil) icon
4. Make your changes
5. Tap "Update Category"

## Deleting Categories

1. Go to Settings → Custom Categories
2. Find the category you want to delete
3. Tap the **Delete** (trash) icon
4. Confirm deletion in the dialog

**⚠️ Note:** Deleting a category does NOT delete existing expenses with that category. Those expenses will keep their category name, but it will display with default styling.

## How Custom Categories Work

### Integration with Analysis

- Custom categories appear in all analysis charts and breakdowns
- They use your chosen colors in pie charts and bar graphs
- They're included in category spending summaries
- Works seamlessly with the existing analysis algorithms

### OCR Keyword Detection

When you scan a receipt:
1. The OCR engine extracts text from the receipt
2. The system searches for keywords from all categories (predefined + custom)
3. If a keyword match is found, that category is automatically selected
4. You can still manually change the category if needed

### Data Persistence

- All custom categories are stored locally using encrypted Hive database
- They're preserved across app restarts
- If you sign in with an account, you can sync them (if cloud sync is enabled)

## Examples

### Example 1: Pet Owner

**Category Name:** Pet Care  
**Emoji:** 🐕  
**Color:** Brown  
**Available In:** Receipt Scanning, Manual Expense  
**Keywords:** vet, veterinary, pet store, petco, petsmart, dog food, cat food, pet supplies

**Use Case:** When you scan a receipt from the vet or pet store, it automatically categorizes as "Pet Care"

### Example 2: Fitness Enthusiast

**Category Name:** Gym & Fitness  
**Emoji:** 🏋️  
**Color:** Orange  
**Available In:** Receipt Scanning, Manual Expense, Subscription  
**Keywords:** gym, fitness, training, workout, health club, wellness, sports

**Use Case:** Track gym membership (subscription), protein supplements (receipts), and personal training sessions (manual)

### Example 3: Coffee Lover

**Category Name:** Coffee & Treats  
**Emoji:** ☕  
**Color:** Brown  
**Available In:** Receipt Scanning, Manual Expense  
**Keywords:** cafe, coffee shop, starbucks, dunkin, espresso, latte, coffeehouse

**Use Case:** Separate coffee expenses from general dining to see your true coffee spending

### Example 4: Small Business Owner

**Category Name:** Business Supplies  
**Emoji:** 💼  
**Color:** Blue Grey  
**Available In:** Receipt Scanning, Manual Expense  
**Keywords:** office depot, staples, business, office supplies, printing, shipping

**Use Case:** Track business-related expenses separately for tax purposes

## Best Practices

### Naming Conventions

- ✅ Use clear, descriptive names
- ✅ Keep names concise (2-3 words max)
- ✅ Use consistent terminology
- ❌ Avoid very generic names like "Stuff" or "Things"
- ❌ Don't duplicate predefined category names

### Keyword Selection

- ✅ Add specific merchant names (e.g., "petco", "petsmart")
- ✅ Include common variations (e.g., "vet", "veterinary")
- ✅ Use lowercase for keywords
- ✅ Add 3-8 keywords per category
- ❌ Don't add too many generic keywords (reduces accuracy)

### Color Selection

- ✅ Choose colors that visually differentiate from existing categories
- ✅ Use color psychology (red for urgent, green for savings, etc.)
- ✅ Group related categories with similar color shades

### Context Selection (Available In)

- Select **Receipt Scanning** if you'll scan receipts for this category
- Select **Manual Expense** if you'll manually enter these expenses
- Select **Subscription** if this category applies to recurring subscriptions
- **Pro Tip:** Select all three for maximum flexibility

## Technical Details

### Storage

- Custom categories are stored in encrypted Hive database
- Type ID: 2 (Hive adapter)
- Location: `customCategoriesBox`

### Data Structure

```dart
CustomCategory {
  id: String (UUID)
  name: String
  emoji: String
  colorValue: int
  keywords: List<String>
  availableIn: List<String> // ['receipt', 'expense', 'subscription']
  createdAt: DateTime
  updatedAt: DateTime
}
```

### API Methods

```dart
// Get all custom categories
LocalStorageService.getAllCustomCategories()

// Get categories by type
LocalStorageService.getCustomCategoriesByType('receipt')
LocalStorageService.getCustomCategoriesByType('expense')
LocalStorageService.getCustomCategoriesByType('subscription')

// Add category
LocalStorageService.addCustomCategory(category)

// Update category
LocalStorageService.updateCustomCategory(category)

// Delete category
LocalStorageService.deleteCustomCategory(categoryId)

// Check if exists
LocalStorageService.customCategoryExists(name, excludeId: id)
```

### CategoryService Integration

The `CategoryService` has been enhanced to seamlessly integrate custom categories:

```dart
// Returns predefined + custom categories
CategoryService.manualExpenseCategories
CategoryService.postCaptureCategories
CategoryService.subscriptionCategories

// Get category info (works for both predefined and custom)
CategoryService.getCategoryInfo(categoryName)
CategoryService.getCategoryColor(categoryName)
CategoryService.getCategoryEmoji(categoryName)

// Check if custom
CategoryService.isCustomCategory(categoryName)
```

## FAQ

### Q: How many custom categories can I create?
**A:** There's no hard limit, but we recommend keeping it under 20 for optimal UX.

### Q: Can I use the same name as a predefined category?
**A:** No, category names must be unique across both predefined and custom categories.

### Q: Will my custom categories sync across devices?
**A:** Currently, custom categories are stored locally. Cloud sync support may be added in future updates.

### Q: What happens to my expenses if I delete a custom category?
**A:** Existing expenses keep their category name but will display with default styling. The data is not lost.

### Q: Can I export my custom categories?
**A:** Not directly in the current version, but they're included in full app data backups.

### Q: Do keywords work with all languages?
**A:** Keywords work best with the language your OCR is configured for. Add keywords in the language of your receipts.

### Q: Can I have the same emoji for multiple categories?
**A:** Yes, emojis don't have to be unique, though unique emojis help with visual identification.

## Troubleshooting

### Custom category not appearing in dropdown
- Check that you selected the correct "Available In" options
- Restart the app to refresh the category cache
- Verify the category was saved successfully

### Keywords not working for OCR detection
- Ensure keywords are spelled correctly (matching the receipt text)
- Keywords are case-insensitive
- Try more specific keywords (brand names work better than generic terms)
- OCR detection happens before you can edit, so keyword matches appear immediately

### Category colors not showing correctly
- Colors are applied correctly in the app - check the analysis page for visual confirmation
- If colors look wrong, try editing the category and selecting a different color

## Future Enhancements

Potential features in future versions:
- 🔄 Cloud sync for custom categories
- 📤 Export/import custom categories
- 🎨 Custom emoji upload (image-based icons)
- 🔍 More granular keyword matching rules
- 📊 Usage statistics per category
- 🏷️ Category groups/hierarchies
- 🌐 Multi-language keyword support

## Support

For questions or issues:
- Check this guide first
- Review the in-app tutorials
- Contact support through Settings → About → Contact Us

---

**Version:** 1.0  
**Last Updated:** October 2025  
**Feature Status:** ✅ Stable

