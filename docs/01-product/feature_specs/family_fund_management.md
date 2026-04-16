# Feature Spec - Family Fund Management

## Overview
Manage shared saving goals and contributions.

## Actors
- Family member A
- Family member B

## Business Rules
- Fund can have optional target and deadline.
- Contribution must reference fund and wallet.
- Contribution reduces wallet balance and increases fund progress.

## States
- Fund: `active`, `inactive`, `completed`
- Contribution: `saved`, `soft_deleted`

## Flow
1. User opens Funds.
2. Creates or selects fund.
3. Adds contribution amount from wallet.
4. System updates fund progress and wallet balance.

## API (Basic)
- `GET /funds`
- `POST /funds`
- `PATCH /funds/{id}`
- `DELETE /funds/{id}`
- `POST /fund-contributions`

## Edge Cases
- Contribution exceeds wallet balance.
- Contribution to inactive fund.
- Target reached and further contributions continue.

## Permissions
- Both family members can manage funds and contributions.
