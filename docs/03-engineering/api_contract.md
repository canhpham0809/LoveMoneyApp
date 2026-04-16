# API Contract - Family Cashbook

## 1. API Conventions

- Base path: `/api/v1`
- Auth: Bearer JWT
- Content type: `application/json`
- All operations are scoped by authenticated user's `couple_id`

Common response envelope:

```json
{
	"data": {},
	"meta": {},
	"error": null
}
```

## 2. Auth and Family

### POST /auth/register
Request:
```json
{ "email": "a@x.com", "password": "secret", "display_name": "A" }
```

### POST /families
Create family space.

### POST /families/invite
Generate invite code/link.

### POST /families/join
Request:
```json
{ "invite_code": "123456" }
```

## 3. Wallets

### GET /wallets
List active wallets.

### POST /wallets
```json
{
	"name": "Family Cash",
	"type": "cash",
	"currency": "VND",
	"is_default": true
}
```

### PATCH /wallets/{id}
Update wallet metadata.

### DELETE /wallets/{id}
Soft delete wallet if allowed.

## 4. Master Data

### Categories
- GET /categories
- POST /categories
- PATCH /categories/{id}
- DELETE /categories/{id}
- POST /categories/merge

Merge request:
```json
{ "source_category_id": "uuid", "target_category_id": "uuid" }
```

### Income sources
- GET /income-sources
- POST /income-sources
- PATCH /income-sources/{id}
- DELETE /income-sources/{id}

### Funds
- GET /funds
- POST /funds
- PATCH /funds/{id}
- DELETE /funds/{id}

### Debt types
- GET /debt-types
- POST /debt-types
- PATCH /debt-types/{id}
- DELETE /debt-types/{id}

## 5. Expenses

### GET /expenses
Query:
- `from_date`
- `to_date`
- `wallet_id`
- `category_id`
- `user_id`

### POST /expenses
```json
{
	"wallet_id": "uuid",
	"category_id": "uuid",
	"amount": 50000,
	"description": "breakfast",
	"date": "2026-04-16"
}
```

Response includes updated wallet balance snapshot.

### PATCH /expenses/{id}
### DELETE /expenses/{id}

## 6. Incomes

### GET /incomes
### POST /incomes
```json
{
	"wallet_id": "uuid",
	"income_source_id": "uuid",
	"amount": 15000000,
	"description": "salary",
	"date": "2026-04-30"
}
```

### PATCH /incomes/{id}
### DELETE /incomes/{id}

## 7. Transfers

### GET /transfers

### POST /transfers
```json
{
	"from_user_id": "uuid",
	"to_user_id": "uuid",
	"from_wallet_id": "uuid",
	"to_wallet_id": "uuid",
	"amount": 2000000,
	"note": "weekly household transfer",
	"date": "2026-04-16"
}
```

Behavior:
- Creates transfer row.
- Creates linked income row for receiver.
- Updates both wallet balances.

## 8. Fund Contributions

### GET /fund-contributions
### POST /fund-contributions
```json
{
	"fund_id": "uuid",
	"wallet_id": "uuid",
	"amount": 1000000,
	"note": "monthly contribution",
	"date": "2026-04-16"
}
```

## 9. Debts and Payments

### Debts
- GET /debts
- POST /debts
- PATCH /debts/{id}
- DELETE /debts/{id}

Create debt request:
```json
{
	"debt_type_id": "uuid",
	"name": "ACB Loan",
	"original_amount": 100000000,
	"creditor_name": "ACB",
	"start_date": "2026-01-01",
	"due_date": "2026-12-31",
	"reminder_days_before": 7
}
```

### Debt payments
- GET /debts/{id}/payments
- POST /debts/{id}/payments

```json
{
	"wallet_id": "uuid",
	"amount": 3000000,
	"date": "2026-04-20",
	"note": "installment"
}
```

## 10. Budgets

### Monthly family budget
- GET /monthly-budgets?month=2026-04
- PUT /monthly-budgets/2026-04

```json
{ "amount": 25000000 }
```

### Category budget
- PUT /categories/{id}/budget

## 11. Quick Add

### POST /quick-add
```json
{ "input": "50k breakfast", "wallet_id": "uuid" }
```

Response:
```json
{
	"data": {
		"parsed_amount": 50000,
		"suggested_category_id": "uuid",
		"confidence": 0.82,
		"fallback_required": false
	}
}
```

## 12. Dashboard and Analytics

### GET /dashboard/summary
Returns:
- family_balance
- monthly_net
- monthly_budget_progress
- debt_due_items
- top_categories

### GET /analytics/expenses
### GET /analytics/incomes
### GET /analytics/funds
### GET /analytics/debts

## 13. Notifications and Reports

### GET /notifications/preferences
### PUT /notifications/preferences

### GET /reports/monthly?month=2026-03

## 14. Error Codes (Examples)

- `AUTH_UNAUTHORIZED`
- `FAMILY_NOT_LINKED`
- `WALLET_NOT_FOUND`
- `INSUFFICIENT_BALANCE`
- `BUDGET_INVALID_MONTH`
- `VALIDATION_ERROR`
