# Feature Spec - Quick Add and Undo

## Overview
Enable ultra-fast transaction logging with recovery action.

## Actors
- Family member A
- Family member B

## Business Rules
- Quick Add accepts natural text input.
- On parse success, create transaction in <= 2 seconds target.
- On parse failure, open full form prefilled.
- Undo available for 3 to 5 seconds after operation.

## States
- Parse: `success`, `fallback_required`
- Snackbar: `shown`, `expired`, `undone`

## Flow
1. User enters text input from home.
2. System parses amount and suggests category.
3. User confirms or adjusts.
4. Transaction saved and undo snackbar shown.

## API (Basic)
- `POST /quick-add`
- `POST /expenses` (or related endpoint after parse)

## Edge Cases
- Ambiguous amount format.
- Empty text.
- Undo tapped after snackbar expired.

## Permissions
- Same as underlying transaction permission rules.
