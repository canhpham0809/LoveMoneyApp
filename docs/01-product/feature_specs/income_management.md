# Feature Spec - Income Management

## Overview
Record incoming money by source and wallet.

## Actors
- Family member A
- Family member B

## Business Rules
- `amount > 0`.
- Income must have source and wallet.
- Income from transfer is system-generated and linked.
- Income creation adds wallet balance.

## States
- `manual`
- `from_transfer`
- `soft_deleted`

## Flow
1. User chooses Income from + menu.
2. Inputs amount, source, wallet, date.
3. Saves record.
4. System stores income and updates wallet balance.

## API (Basic)
- `GET /incomes`
- `POST /incomes`
- `PATCH /incomes/{id}`
- `DELETE /incomes/{id}`

## Edge Cases
- Attempt to manually set `is_from_transfer = true`.
- Invalid source reference.
- Duplicate salary submissions by mistake.

## Permissions
- Members can manage incomes in their own family scope.
