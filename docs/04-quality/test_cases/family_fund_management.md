# Test Cases - Family Fund Management

## Happy Path
- TC-FND-001: Create fund and set target amount.
- TC-FND-002: Add contribution and verify wallet deduction.
- TC-FND-003: Progress reaches 100 percent and success event fires.

## Edge Cases
- TC-FND-101: Contribution after target reached.
- TC-FND-102: Contribution rollback on wallet update failure.
- TC-FND-103: Fund deactivated but historical data still visible.

## Invalid Inputs
- TC-FND-201: Negative target amount.
- TC-FND-202: Missing fund_id in contribution.
- TC-FND-203: Invalid deadline format.
