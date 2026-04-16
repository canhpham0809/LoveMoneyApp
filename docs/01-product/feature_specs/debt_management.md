# Feature Spec - Debt Management

## Overview
Track debts, due dates, and payment history.

## Actors
- Debtor member
- Partner member

## Business Rules
- Debt has original amount and remaining amount.
- Payment decreases remaining amount.
- Debt closes automatically at remaining amount = 0.

## States
- Debt: `active`, `overdue`, `closed`
- Payment: `saved`, `soft_deleted`

## Flow
1. User creates debt record.
2. User adds due date and reminder window.
3. User records payment from selected wallet.
4. System updates debt remaining and wallet balance.

## API (Basic)
- `GET /debts`
- `POST /debts`
- `PATCH /debts/{id}`
- `DELETE /debts/{id}`
- `GET /debts/{id}/payments`
- `POST /debts/{id}/payments`

## Edge Cases
- Payment amount greater than remaining amount.
- Due date in past at creation.
- Payment against closed debt.

## Permissions
- Both members can view debts and payments in family scope.
