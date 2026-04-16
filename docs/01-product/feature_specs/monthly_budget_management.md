# Feature Spec - Monthly Budget Management

## Overview
Control spending using monthly family budget and per-category budget.

## Actors
- Family member A
- Family member B

## Business Rules
- Monthly budget is scoped by month (`YYYY-MM`).
- Category budget is independent from monthly total budget.
- Alerts at 80 percent and 100 percent thresholds.

## States
- Budget state: `normal`, `warning_80`, `exceeded`

## Flow
1. User sets monthly family budget.
2. User optionally sets category budgets.
3. System tracks current spend in real time.
4. Alerts are triggered when thresholds are crossed.

## API (Basic)
- `GET /monthly-budgets`
- `PUT /monthly-budgets/{month}`
- `PUT /categories/{id}/budget`

## Edge Cases
- Invalid month format.
- Negative budget amount.
- Budget updated mid-month after overspending.

## Permissions
- Both members can configure and view budgets.
