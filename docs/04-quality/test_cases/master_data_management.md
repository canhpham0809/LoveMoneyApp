# Test Cases - Master Data Management

## Happy Path
- TC-MDM-001: Create category and use it in expense.
- TC-MDM-002: Deactivate income source and keep history intact.
- TC-MDM-003: Merge category A into B and re-map transactions.

## Edge Cases
- TC-MDM-101: Attempt to delete referenced master record.
- TC-MDM-102: Merge into inactive category.
- TC-MDM-103: Duplicate names with different case.

## Invalid Inputs
- TC-MDM-201: Empty name.
- TC-MDM-202: Invalid color code.
- TC-MDM-203: Invalid sort_order value.
