# Feature Spec - Master Data Management

## Overview
Manage shared dictionaries used across transactions.

## Actors
- Family member A
- Family member B

## Business Rules
- Master data includes categories, income sources, funds, debt types, wallets.
- Referenced records cannot be hard deleted.
- Use `is_active` or soft delete for deprecation.

## States
- `active`
- `inactive`
- `soft_deleted`

## Flow
1. User opens master data section.
2. Creates or edits a record.
3. Deactivates records no longer needed.
4. Optionally merges duplicate categories.

## API (Basic)
- `GET/POST/PATCH/DELETE` on each master data endpoint.
- `POST /categories/merge` for category merge action.

## Edge Cases
- Duplicate names.
- Deactivate default mandatory records.
- Merge into inactive target.

## Permissions
- Both members can manage family master data.
