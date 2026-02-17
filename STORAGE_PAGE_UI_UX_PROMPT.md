# Storage Page (My Bills) — UI/UX Brief for Figma

**App:** SmartReceipt · **Screen:** Storage / My Bills · **Nav:** Bottom tab “Storage” (folder icon).

## Goal
Single place to **find, filter, and manage all receipts**: scanned, manual, subscriptions. Users should **search** (by title/tags), **filter** (source, category, location, year/month), **view** list grouped by year → month → category, and **act** (edit, delete, export). Optional: shared expenses block and **calendar view** (premium). Feel clear, fast, trustworthy.

## What We Have Done
- **App bar:** Title “My Bills”, back → Home; shared-expenses toggle (people icon); Calendar button + “Premium” badge; sort menu (newest/oldest, name A–Z/Z–A, total high/low).
- **Search:** Full-width, “Search receipts…”, 12px radius, grey fill.
- **Shared expenses (optional):** Summary strip + list of unpaid shared expenses when toggle on.
- **Filters:** Grey block “Filter Receipts” + Source (All/Scanned/Manual), Location, Category (multi-select chips). Responsive layout.
- **Year/month:** Horizontal scroll chips; year then months. Selected = blue #4facfe, unselected = grey, pill ~20px.
- **List:** Grouped by Year → Month → Category. **Bill card:** 80px left = thumbnail or brand/letter icon; body = title (bold 16px), date (grey 12px), amount+currency (blue 14px); right = up to 2 category tags or “Other”; subscription badge top-right if subscription. White card, 12px radius, light shadow. Tap/long-press → options.
- **Bill options (bottom sheet):** Edit, Delete, Export & Share (premium). Delete → confirmation dialog.
- **Empty states:** No bills = “No receipts saved yet” + Scan Receipt + Manual Entry; variants for “no manual” / “no scanned” with specific CTAs.
- **Calendar view (premium):** Month nav, 7-day grid (Mon–Sun), dots for days with receipts, selected day blue; footer strip “Receipts for [date]” + horizontal small cards.
- **Other:** Pull-to-refresh, pagination (20/page), bottom nav (Home, Analysis, Scan, Storage, Profile), premium renewal label bottom-right.
- **Tokens:** Primary #4facfe; white + grey[50/100]; 12px cards/inputs, 20px pills; amber “Premium” badge; light card shadows.

## What We Want From Figma
1. Hierarchy & scanability (month groups, cards, typography).
2. Filter/sort UX (clearer, less clutter).
3. Card design (thumbnail vs letter icon, subscription badge, tags).
4. Empty states (on-brand, clear CTAs).
5. Calendar (month strip, day cells, receipt strip).
6. Bottom sheet (Edit/Delete/Export consistent and safe).
7. Shared expenses placement vs main content.
8. Responsive & accessibility (touch targets, contrast).
9. Premium cues without feeling locked.
10. Consistency with rest of app.

**Deliverables:** List view (search, filters, year/month, 2–3 cards); Empty state; Bill card variants (scanned, manual, subscription); Bill options sheet; Calendar view; optional Filter + Shared expenses as components.
