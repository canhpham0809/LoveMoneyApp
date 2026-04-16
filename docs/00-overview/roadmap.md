# Family Cashbook - Product Roadmap

## Phase 1 - MVP (Digital Notebook)

Goal: Ship core shared household tracking for 2-member family.

Scope:
- Onboarding and family linking.
- Single default wallet (Family Cash).
- Expense, Income (manual), Fund contribution.
- Quick Add baseline and Undo snackbar.
- Dashboard with balance, net, and recent feed.
- Master data CRUD (category, income source, fund, debt type).
- Real-time sync for 2 devices.

Exit criteria:
- Users can record and review daily family cashflow.
- Balance and monthly net are reliable.

## Phase 2 - Core Complete

Goal: Complete money movement and control features.

Scope:
- Internal transfer with auto-linked income.
- Debt management + debt payment tracking.
- Multi-wallet mode.
- Monthly family budget and category budget alerts.
- Full analytics by pillar.
- Search, export CSV/Excel.
- Notifications (daily reminder, threshold alerts, summaries).

Exit criteria:
- All financial pillars operational end-to-end.
- Budget and debt alerts working in production.

## Phase 3 - AI Intelligence

Goal: Deliver practical AI insights with safety gating.

Scope:
- AI Safe Mode gating (>=30 transactions or >=14 active days).
- Spending insights and anomaly summaries.
- Auto-categorize enhancement.
- Debt reminder intelligence.
- End-month forecast and monthly report.
- Saving suggestions based on surplus and fund progress.

Exit criteria:
- AI outputs are useful, explainable, and non-intrusive.

## Phase 4 - Polish and Growth

Goal: Improve retention and convenience.

Scope:
- Widgets for quick add and balance preview.
- Recurring transactions.
- Receipt scan (camera OCR).
- Backup and restore hardening.
- PWA/Web expansion.

Exit criteria:
- Improved retention and lower daily logging friction.

## Delivery Notes

- Prioritize quality gates before enabling AI features broadly.
- Keep API and schema backward compatible across phases where possible.
- Any scope change must update:
	- Product requirements
	- API contract
	- Database schema
	- Test cases
