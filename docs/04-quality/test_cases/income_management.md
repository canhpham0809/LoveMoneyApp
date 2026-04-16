# Test Cases - Income Management

## Happy Path
- TC-INC-001: Create manual income with valid source and wallet.
- TC-INC-002: Edit income amount and verify wallet adjustment.
- TC-INC-003: Filter incomes by date range and source.

## Edge Cases
- TC-INC-101: Income from transfer is read-only for transfer fields.
- TC-INC-102: Late income posting affects monthly net.
- TC-INC-103: Offline income replay with duplicate detection.

## Invalid Inputs
- TC-INC-201: Invalid income_source_id.
- TC-INC-202: Amount with unsupported format.
- TC-INC-203: Missing wallet_id.
