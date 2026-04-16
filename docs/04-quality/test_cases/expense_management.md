# Test Cases - Expense Management

## Happy Path
- TC-EXP-001: Create expense with valid category, wallet, and amount.
- TC-EXP-002: Edit expense updates feed and recalculates totals.
- TC-EXP-003: Soft delete expense hides it from default list.

## Edge Cases
- TC-EXP-101: Expense created near month boundary affects correct budget month.
- TC-EXP-102: Update category after category merge.
- TC-EXP-103: Offline expense syncs correctly when network returns.

## Invalid Inputs
- TC-EXP-201: Zero amount.
- TC-EXP-202: Missing category_id.
- TC-EXP-203: Invalid date format.
