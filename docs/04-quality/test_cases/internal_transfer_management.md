# Test Cases - Internal Transfer Management

## Happy Path
- TC-TRF-001: Create transfer and linked income record.
- TC-TRF-002: Source and destination wallet balances update correctly.
- TC-TRF-003: Transfer appears in both users' feed.

## Edge Cases
- TC-TRF-101: Source and destination wallet are the same.
- TC-TRF-102: Linked income creation transient failure rollback.
- TC-TRF-103: Duplicate submission due to retry.

## Invalid Inputs
- TC-TRF-201: Missing destination wallet.
- TC-TRF-202: Negative transfer amount.
- TC-TRF-203: from_user_id not in current family.
