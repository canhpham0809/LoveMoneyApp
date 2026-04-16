# Product Requirements - Family Cashbook v2

## 1. Overview

Family Cashbook is a shared household finance app for exactly 2 members in one family space.

Product goals:
- Log fast.
- Keep balance accurate.
- Provide shared transparency.
- Drive better decisions via budgeting and AI insights.

## 2. Feature List

Core features:
- Onboarding and family linking.
- Wallet and balance system.
- Expense management.
- Internal transfer with auto-linked income.
- Income management.
- Family fund management.
- Debt and debt payment management.
- Monthly family budget and category budgets.
- Dashboard and analytics.
- Notifications.
- Quick Add and Undo/Edit UX.
- AI insights and recommendations (gated).

Support features:
- Master data CRUD.
- Search and filtering.
- Export CSV/Excel.
- Family settings and security.

## 3. User Stories

### 3.1 Onboarding and family linking
- As a new user, I want to create a family space so I can manage household money.
- As a partner, I want to join via invite code/link so both of us can share the same data.

### 3.2 Wallet and balance
- As a user, I want to see current family balance so I know available money.
- As a user, I want to assign each transaction to a wallet so balance updates correctly.

### 3.3 Expense and income
- As a user, I want to add expense quickly so I can maintain daily tracking.
- As a user, I want to add income by source so I can see net monthly cashflow.

### 3.4 Internal transfer
- As a user, I want to record spouse transfer so movement is transparent.
- As a receiver, I want transfer income auto-linked so data stays consistent.

### 3.5 Fund and debt
- As a family, we want to contribute to savings funds so we can reach goals.
- As a debtor, I want debt reminders so I can avoid overdue payments.

### 3.6 Budgeting and alerts
- As a user, I want monthly budget progress so I can control spending.
- As a user, I want alerts at budget thresholds so I can react early.

### 3.7 AI and reports
- As a user, I want monthly insights so I understand spending patterns.
- As a user, I want savings suggestions so I can allocate surplus effectively.

## 4. High-Level Flows

### 4.1 Add expense
1. User taps +.
2. Selects Expense.
3. Enters amount, category, wallet, date.
4. Saves transaction.
5. System updates wallet balance and syncs to partner.

### 4.2 Internal transfer
1. User taps + and chooses Transfer.
2. Selects source and destination wallets.
3. Enters amount.
4. Saves transfer.
5. System creates linked income for receiver and updates both balances.

### 4.3 Quick Add
1. User enters natural text like 50k breakfast.
2. System parses amount and suggests category.
3. User confirms.
4. Transaction saved with undo snackbar.

### 4.4 Debt payment
1. User opens debt detail.
2. Adds payment amount and wallet.
3. System records payment, decreases remaining debt and wallet balance.
4. Debt status updates if fully paid.

## 5. Business Rules

- Family size is exactly 2 members.
- All records are scoped by `couple_id`.
- No hard delete for referenced data.
- Soft delete and audit tracking are mandatory.
- AI features are gated until usage threshold is met.

## 6. Non-Functional Requirements

- Add transaction <= 5 seconds.
- Quick Add <= 2 seconds on success path.
- Home load < 1 second target.
- Device sync visibility < 3 seconds typical.
- Availability >= 99.5%.
- Offline writes are queued and retried.

## 7. Out of Scope (Current)

- Full accounting double-entry system.
- Advanced investment portfolio valuation.
- Desktop app.