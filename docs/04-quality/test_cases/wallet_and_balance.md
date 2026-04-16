# Test Cases - Wallet and Balance

## Happy Path
- TC-WAL-001: Create default wallet.
- TC-WAL-002: Expense decreases wallet balance.
- TC-WAL-003: Income increases wallet balance.
- TC-WAL-004: Transfer updates source and destination wallets correctly.

## Edge Cases
- TC-WAL-101: Attempt outgoing action with insufficient balance.
- TC-WAL-102: Soft delete non-default wallet with history.
- TC-WAL-103: Reconciliation job finds and fixes drift.

## Invalid Inputs
- TC-WAL-201: Negative opening balance.
- TC-WAL-202: Unknown wallet type.
- TC-WAL-203: Null currency code.
