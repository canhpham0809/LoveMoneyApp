# Feature Spec - Expense Management

## Overview
Record household spending with category and wallet assignment.

## Actors
- Family member A
- Family member B

## Business Rules
- `amount > 0`.
- Expense must have `category_id`, `wallet_id`, and `date`.
- Expense creation subtracts wallet balance.

## States
- `draft`
- `saved`
- `soft_deleted`

## Flow
1. User taps + and selects Expense.
2. User inputs amount, category, wallet, optional note.
3. User saves transaction.
4. System stores row, updates wallet balance, emits realtime update.

## API (Basic)
- `GET /expenses`
- `POST /expenses`
- `PATCH /expenses/{id}`
- `DELETE /expenses/{id}`

## Edge Cases
- Invalid amount format.
- Missing required fields.
- Editing historical expense changes budget metrics.

## Permissions
- Members can access only records under their `couple_id`.
