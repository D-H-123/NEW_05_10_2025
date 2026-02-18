# Future Enhancement: "Shared Wallets" (Replaces "Family Budget")

**Status:** Planned — Future Implementation  
**Added:** Feb 18, 2026  
**Priority:** Medium-High (premium differentiator)

---

## Why Rebrand

"Family Budget" alienates students, roommates, couples, and friend groups.  
Rename to **"Shared Wallets"** (or "Groups") to serve all audiences.

**Tagline:** "Scan it. Split it. Settle it."

---

## Target Personas

| Persona | Use Case | Duration |
|---|---|---|
| Roommates / Students | Rent, utilities, groceries, subscriptions | Ongoing, monthly cycles |
| Friends on a Trip | Hotels, restaurants, fuel, activities | Temporary, days/weeks |
| Family | Household budget, kids, groceries | Ongoing |
| Couples | Shared expenses, rent | Ongoing |
| Event Groups | Birthday gift pool, office lunch, party | One-time |

---

## Group Templates

When creating a group, user picks a template that pre-configures settings:

| Setting | Roommates | Trip | Family | Event | Custom |
|---|---|---|---|---|---|
| Duration | Ongoing | Has end date | Ongoing | One-time | Flexible |
| Budget limit | Optional | Per-trip total | Monthly limit | Fixed pool | Optional |
| Split default | Equal | Per-expense | Flexible | Equal | Any |
| Settlement | Monthly reminder | End of trip | No pressure | After event | Custom |
| Categories | Rent, Utilities, Groceries, Subs | Transport, Food, Stay, Activities | Groceries, Kids, Home, Bills | Single category | Custom |
| Key metric | "You owe / You're owed" | "Trip total / Your share" | "Budget X% used" | "Collected X of Y" | Flexible |

---

## Core Feature: "Scan & Split" Flow

After scanning a receipt, user sees an option:

```
[Receipt recognized — Total: $67.50]

  Add to:
    ○ Personal only
    ● Split with group

  Select group: [🏠 The Flat ▼]

  Split method:
    ○ Equal (3 people = $22.50 each)
    ○ Custom amounts

  [Add to Group]
```

This is the unique differentiator — scan a receipt and split it in one flow.  
No competitor connects receipt scanning → group expense splitting.

---

## Smart Settlement (Minimum Transfers)

Instead of per-transaction settlements, calculate minimum transfers at settlement time:

```
🏠 The Flat — February

Total group spending: $840
Fair share each: $280

✅ You paid: $310 (+$30)
💸 Alex paid: $250 (-$30)
💸 Sam paid: $280 (even)

To settle up:
  Alex → You: $30

[Remind Alex]  [Mark Settled]
```

Settlement timing depends on template:
- Roommates → monthly reminder
- Trip → end-of-trip prompt
- Event → after event closes

---

## Unified Budget Integration (Home Page)

Merge group spending into the existing personal budget overview:

```
Monthly Budget: $2,000
├── Personal spending:     $650
├── My share from groups:
│   ├── 🏠 The Flat:       $380
│   ├── ✈️ Bali Trip:      $220
│   └── 🎉 Jake's Gift:    $25
├── Total spent:           $1,275
└── Remaining:             $725
```

User sees ONE budget number with a breakdown of personal vs group contributions.  
Remove the separate "promo card" approach — integrate natively.

---

## Unified Analytics (Analysis Page)

Add a toggle on the existing analysis page:

```
[Personal]  [Groups]  [All]
```

- Personal: Current behavior (solo expenses only)
- Groups: Your share of group expenses by category
- All: Combined view — true picture of spending

---

## Entry Points (Replace Promo Card)

- Post-scan: "Split with group?" option after every receipt scan
- Home page: Group spending integrated into budget overview card
- Dedicated section: Groups list accessible from home or navigation
- Manual entry: "Shared" toggle when adding manual expenses

---

## What to Keep from Current Implementation

- ✅ Invite code system (6-character codes)
- ✅ Real-time Firestore sync
- ✅ Member management with roles
- ✅ SharedBudget / BudgetMember / MemberExpense models (extend them)
- ✅ Premium gating (Pro tier)

## What to Change

- ❌ Remove "Family Budget" naming everywhere
- ❌ Remove standalone promo card from home page
- ❌ Remove separate expense entry in collaboration page (use main scan/entry flow with "shared" toggle)
- 🔄 Rename BudgetCollaborationPage → SharedWalletsPage (or GroupsPage)
- 🔄 Add group templates to creation flow
- 🔄 Merge group spending into personal budget dashboard
- 🔄 Add analysis page toggle for group vs personal

## What Stays Premium

- Creating/joining groups → Pro tier
- Scan & Split flow → Pro tier
- Smart settlement → Pro tier

---

## Implementation Order (Suggested)

1. **Phase 1 — Rebrand & Templates:** Rename to Shared Wallets, add group templates, update UI copy
2. **Phase 2 — Scan & Split:** Post-scan "split with group" flow (equal + custom splits)
3. **Phase 3 — Unified Budget:** Merge group spending into home page budget overview
4. **Phase 4 — Unified Analytics:** Add Personal/Groups/All toggle on analysis page
5. **Phase 5 — Smart Settlement:** Minimum-transfer calculation + settlement reminders

---

## NOT in Scope (Excluded)

- ~~Item-level splitting from scanned receipts~~ (OCR not reliable enough yet)
- ~~Color-coded donut chart differentiating personal vs group on analysis page~~

---

*This document captures the brainstorming session for the Shared Wallets redesign.  
Revisit when ready to implement.*
