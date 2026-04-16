# Test Cases - AI and Notification System

## Happy Path
- TC-AIN-001: AI remains locked before eligibility threshold.
- TC-AIN-002: AI unlocks after 30 transactions.
- TC-AIN-003: Monthly report notification sent on day 1.

## Edge Cases
- TC-AIN-101: User disables notification type and receives none.
- TC-AIN-102: Duplicate event prevention for same threshold.
- TC-AIN-103: AI suggestion confidence below threshold shown as suggestion only.

## Invalid Inputs
- TC-AIN-201: Invalid notification preference payload.
- TC-AIN-202: Missing required fields in report query.
- TC-AIN-203: Unauthorized attempt to access another family's report.
