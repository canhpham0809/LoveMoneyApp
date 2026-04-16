# Test Cases - Quick Add and Undo

## Happy Path
- TC-QAD-001: Parse input 50k breakfast and create expense.
- TC-QAD-002: Undo create within snackbar window restores state.
- TC-QAD-003: Parse includes wallet and category defaults.

## Edge Cases
- TC-QAD-101: Ambiguous text falls back to full form.
- TC-QAD-102: Undo after edit reverts to previous values.
- TC-QAD-103: Undo action while offline queue pending.

## Invalid Inputs
- TC-QAD-201: Empty quick add input.
- TC-QAD-202: Unsupported amount token.
- TC-QAD-203: Input too long beyond limit.
