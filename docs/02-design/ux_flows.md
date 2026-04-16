# UX Flows - Family Cashbook

## 1. Design Principles

- Fast capture first.
- Balance always visible.
- Shared context for both members.
- Safe defaults and reversible actions.

## 2. Primary Journeys

### 2.1 First-time setup
1. User A registers.
2. Creates family space.
3. Sets currency and language.
4. Shares invite code/link.
5. User B joins.
6. App seeds default master data.

Success criteria:
- Both users can see the same dashboard and data.

### 2.2 Add expense from full form
1. Tap +.
2. Select Expense.
3. Enter amount.
4. Select category.
5. Select wallet.
6. Optional description and date.
7. Save.
8. Show snackbar with Undo.

Success criteria:
- Transaction appears in feed.
- Wallet balance updates immediately.

### 2.3 Quick Add from home
1. User enters short text (example: 50k breakfast).
2. System parses amount and suggests category.
3. User confirms.
4. Save and show Undo snackbar.

Fallback:
- If parse confidence is low, open full form prefilled.

### 2.4 Internal transfer
1. Tap + -> Transfer.
2. Select sender and receiver wallets.
3. Enter amount and note.
4. Save.
5. System creates transfer + linked receiver income.

### 2.5 Fund contribution
1. Open Funds.
2. Choose fund.
3. Tap Contribute.
4. Enter amount, wallet, date.
5. Save and refresh progress.

### 2.6 Debt payment
1. Open Debt detail.
2. Tap Add payment.
3. Enter amount and wallet.
4. Save.
5. Remaining amount recalculates.

## 3. Edit and Recovery Patterns

- Tap item: full detail edit.
- Swipe item: quick edit.
- Long press: duplicate.
- Snackbar Undo: available after create, update, delete.

## 4. Budget and Reminder Flows

- Category budget alert at 80 and 100 percent.
- Monthly budget alert at 80 and 100 percent.
- Debt reminder at configured days before due date.
- Overdue debt reminder repeats until resolved.

## 5. AI Visibility Rules

AI cards are shown only if one of the following is true:
- At least 30 transactions.
- At least 14 active days.

Else:
- Show neutral locked-state message encouraging more usage data.
