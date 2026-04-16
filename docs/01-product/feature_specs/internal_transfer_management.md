# Feature Spec - Internal Transfer Management

## Overview
Track money transfer between partners and auto-create linked receiver income.

## Actors
- Sender member
- Receiver member

## Business Rules
- Source and destination users must belong to same family.
- Source and destination wallets are required.
- Transfer creates exactly one linked income record.
- Family net worth should remain unchanged.

## States
- `created`
- `linked_income_created`
- `reverted`

## Flow
1. Sender opens Transfer form.
2. Inputs amount, source wallet, destination wallet.
3. Saves transfer.
4. System stores transfer, creates linked income, updates both balances.

## API (Basic)
- `GET /transfers`
- `POST /transfers`

## Edge Cases
- Transfer to same wallet.
- Source balance insufficient.
- Linked income creation fails after transfer write.

## Permissions
- Both members can create and view family transfers.
