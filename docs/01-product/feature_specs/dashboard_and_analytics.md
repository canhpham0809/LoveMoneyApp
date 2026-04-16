# Feature Spec - Dashboard and Analytics

## Overview
Provide real-time household overview and trend analytics.

## Actors
- Family member A
- Family member B

## Business Rules
- Dashboard must show family balance and monthly net.
- Analytics are read-only derived views.
- Filters by date, member, wallet, category are supported.

## States
- Dashboard data: `loading`, `ready`, `error`

## Flow
1. User opens Home dashboard.
2. App fetches summary and recent activity.
3. User opens analytics tabs.
4. App renders chart datasets by pillar.

## API (Basic)
- `GET /dashboard/summary`
- `GET /analytics/expenses`
- `GET /analytics/incomes`
- `GET /analytics/funds`
- `GET /analytics/debts`

## Edge Cases
- No transactions for selected period.
- Large date ranges causing slow query.
- Missing denormalized fields in old records.

## Permissions
- Only family members can view family analytics.
