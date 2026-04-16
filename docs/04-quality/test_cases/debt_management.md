# Test Cases - Debt Management

## Happy Path
- TC-DBT-001: Create debt with due date and reminder.
- TC-DBT-002: Add debt payment and reduce remaining amount.
- TC-DBT-003: Debt auto-closes at remaining amount zero.

## Edge Cases
- TC-DBT-101: Payment exactly equals remaining amount.
- TC-DBT-102: Overdue reminder repeats daily until resolved.
- TC-DBT-103: Editing due date updates reminder schedule.

## Invalid Inputs
- TC-DBT-201: Payment amount exceeds remaining amount.
- TC-DBT-202: Missing creditor_name.
- TC-DBT-203: Invalid reminder_days_before value.
