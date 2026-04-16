# Feature Spec - Wallet and Balance

## Overview
Track available money per wallet and family total balance.

## Actors
- Family member A
- Family member B

## Business Rules
- Every financial transaction must reference a wallet.
- Balance updates must follow transaction type rules.
- At least one active wallet must exist.

## States
- Wallet active/inactive
- Wallet default/non-default

## Flow
1. User creates or selects wallet.
2. User records transaction with wallet.
3. System updates wallet balance.
4. Dashboard refreshes family balance and wallet breakdown.

## API (Basic)
- `GET /wallets`
- `POST /wallets`
- `PATCH /wallets/{id}`
- `DELETE /wallets/{id}` (soft delete)

## Edge Cases
- Insufficient wallet balance for outgoing action.
- Deleting wallet that has historical transactions.
- Multiple default wallets attempted.

## Permissions
- Both family members can CRUD wallets in their family scope.
