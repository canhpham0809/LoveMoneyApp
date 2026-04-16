# Test Cases - Monthly Budget Management

## Happy Path
- TC-BGT-001: Set monthly family budget for valid month.
- TC-BGT-002: Set category budget and track usage.
- TC-BGT-003: Trigger alerts at 80 and 100 percent.

## Edge Cases
- TC-BGT-101: Update budget after threshold already crossed.
- TC-BGT-102: Month change resets progress correctly.
- TC-BGT-103: Simultaneous expenses crossing threshold once.

## Invalid Inputs
- TC-BGT-201: Invalid month key format.
- TC-BGT-202: Negative budget amount.
- TC-BGT-203: Non-numeric budget value.
