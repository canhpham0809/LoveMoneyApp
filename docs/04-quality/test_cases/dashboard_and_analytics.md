# Test Cases - Dashboard and Analytics

## Happy Path
- TC-DAS-001: Dashboard shows family balance and monthly net.
- TC-DAS-002: Expense analytics returns valid category distribution.
- TC-DAS-003: Fund and debt analytics render with valid datasets.

## Edge Cases
- TC-DAS-101: No data period returns empty-state safely.
- TC-DAS-102: Large date window still paginates correctly.
- TC-DAS-103: Late-arriving sync event updates charts.

## Invalid Inputs
- TC-DAS-201: Invalid date range query.
- TC-DAS-202: Unauthorized analytics access for non-member.
- TC-DAS-203: Invalid filter ids.
