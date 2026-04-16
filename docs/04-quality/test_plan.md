# Test Plan - Family Cashbook

## 1. Scope

In scope:
- Onboarding and family linking.
- Wallet and balance updates.
- Expense, income, transfer, fund, debt, debt payment.
- Monthly and category budget alerts.
- Quick Add and Undo behavior.
- Dashboard and analytics outputs.
- Notification triggers.
- Permissions and data isolation by `couple_id`.

Out of scope for current cycle:
- OCR receipt scan.
- Desktop client.

## 2. Test Types

- Unit tests:
	- parsing logic
	- balance calculators
	- threshold evaluators
- Integration tests:
	- transaction write paths and wallet updates
	- transfer to linked income consistency
	- debt payment to remaining balance consistency
- API tests:
	- endpoint contract validation
	- auth and authorization
- End-to-end tests:
	- critical user journeys on mobile
- Non-functional tests:
	- latency targets
	- sync behavior
	- offline queue recovery

## 3. Test Environment

- Staging backend with representative data.
- Two test accounts linked as one family.
- Mobile test devices (iOS and Android).
- Push notification sandbox for trigger verification.

## 4. Entry Criteria

- Feature specs approved.
- API contract and schema stable for sprint.
- Build deployed to test environment.
- Test data seeded.

## 5. Exit Criteria

- 100 percent pass on P0 and P1 test cases.
- No open critical or high severity defects.
- Wallet balance reconciliation has no unresolved mismatch.
- Security and RLS checks passed.

## 6. Risk-Based Priorities

P0:
- Incorrect balance updates.
- Cross-family data leakage.
- Transfer and linked-income inconsistency.
- Debt remaining amount miscalculation.

P1:
- Budget threshold trigger mismatch.
- Notification duplication or missed alerts.
- Quick Add parse errors causing wrong records.

P2:
- Minor UI formatting issues.
- Low-impact analytics display inconsistencies.

## 7. Traceability

Each core feature has dedicated test case file under:
- `docs/04-quality/test_cases/`

Coverage rule:
- Happy path
- Edge cases
- Invalid input and permission scenarios

## 8. Reporting

- Daily defect summary during active QA window.
- Release readiness report with:
	- pass/fail by feature
	- severity breakdown
	- blocked test cases
