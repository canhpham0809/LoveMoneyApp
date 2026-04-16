# Database Schema - Family Cashbook

## 1. Conventions

- Naming: snake_case.
- Table naming: plural nouns.
- IDs: UUID primary keys.
- Money fields: numeric(14,2).
- Timestamps: timestamptz.

Mandatory governance columns in core tables:
- `couple_id`
- `created_at`, `updated_at`, `updated_by`
- `is_deleted`, `deleted_at`

## 2. Core Tables

### 2.1 users

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| email | text unique | No | |
| display_name | text | No | |
| role_label | text | Yes | |
| avatar_url | text | Yes | |
| created_at | timestamptz | No | default now() |
| updated_at | timestamptz | No | |

### 2.2 couples

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| name | text | No | Family name |
| currency | text | No | default VND |
| language | text | No | default vi |
| monthly_budget_amount | numeric(14,2) | Yes | Optional quick setting |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |

### 2.3 couple_members

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| user_id | uuid fk users.id | No | |
| joined_at | timestamptz | No | |

Constraint:
- Unique (couple_id, user_id)
- Max 2 active members per couple enforced by business logic

### 2.4 wallets

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| name | text | No | |
| type | text | No | cash, bank, ewallet, other |
| balance | numeric(14,2) | No | denormalized |
| currency | text | No | |
| is_default | boolean | No | |
| is_active | boolean | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.5 categories

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| name | text | No | |
| icon | text | Yes | |
| color | text | Yes | |
| budget_limit | numeric(14,2) | Yes | monthly per-category |
| sort_order | int | Yes | |
| is_active | boolean | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.6 income_sources

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| name | text | No | |
| icon | text | Yes | |
| type | text | No | salary, investment, bonus, freelance, rental, gift, other |
| is_active | boolean | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.7 funds

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| name | text | No | |
| icon | text | Yes | |
| target_amount | numeric(14,2) | Yes | |
| current_amount | numeric(14,2) | No | denormalized |
| deadline | date | Yes | |
| color | text | Yes | |
| is_active | boolean | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.8 debt_types

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| name | text | No | |
| is_active | boolean | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.9 expenses

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| user_id | uuid fk users.id | No | |
| wallet_id | uuid fk wallets.id | No | |
| category_id | uuid fk categories.id | No | |
| category_name | text | Yes | denormalized |
| category_icon | text | Yes | denormalized |
| amount | numeric(14,2) | No | |
| description | text | Yes | |
| date | date | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.10 incomes

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| user_id | uuid fk users.id | No | |
| wallet_id | uuid fk wallets.id | No | |
| income_source_id | uuid fk income_sources.id | No | |
| amount | numeric(14,2) | No | |
| description | text | Yes | |
| is_from_transfer | boolean | No | |
| linked_transfer_id | uuid fk transfers.id | Yes | nullable |
| date | date | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.11 transfers

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| from_user_id | uuid fk users.id | No | |
| to_user_id | uuid fk users.id | No | |
| from_wallet_id | uuid fk wallets.id | No | |
| to_wallet_id | uuid fk wallets.id | No | |
| amount | numeric(14,2) | No | |
| note | text | Yes | |
| linked_income_id | uuid fk incomes.id | Yes | set post-create |
| date | date | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.12 fund_contributions

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| user_id | uuid fk users.id | No | |
| fund_id | uuid fk funds.id | No | |
| wallet_id | uuid fk wallets.id | No | |
| amount | numeric(14,2) | No | |
| note | text | Yes | |
| date | date | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.13 debts

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| user_id | uuid fk users.id | No | |
| debt_type_id | uuid fk debt_types.id | No | |
| name | text | No | |
| original_amount | numeric(14,2) | No | |
| remaining_amount | numeric(14,2) | No | denormalized |
| creditor_name | text | No | |
| start_date | date | No | |
| due_date | date | Yes | |
| reminder_days_before | int | Yes | |
| note | text | Yes | |
| is_closed | boolean | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.14 debt_payments

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| debt_id | uuid fk debts.id | No | |
| wallet_id | uuid fk wallets.id | No | |
| amount | numeric(14,2) | No | |
| date | date | No | |
| note | text | Yes | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

### 2.15 monthly_budgets

| Column | Type | Null | Note |
|---|---|---|---|
| id | uuid pk | No | |
| couple_id | uuid fk couples.id | No | |
| month | text | No | YYYY-MM |
| amount | numeric(14,2) | No | |
| created_at | timestamptz | No | |
| updated_at | timestamptz | No | |
| updated_by | uuid fk users.id | Yes | |
| is_deleted | boolean | No | |
| deleted_at | timestamptz | Yes | |

## 3. Relationships Summary

- couples 1-n wallets, categories, income_sources, funds, debt_types.
- wallets referenced by expenses, incomes, transfers, fund_contributions, debt_payments.
- transfers 1-1 incomes for linked receiver income path.
- debts 1-n debt_payments.
- funds 1-n fund_contributions.

## 4. Suggested Indexes

- `idx_wallets_couple_id`
- `idx_expenses_couple_date`
- `idx_expenses_wallet_id`
- `idx_incomes_couple_date`
- `idx_transfers_couple_date`
- `idx_fund_contributions_fund_date`
- `idx_debts_couple_due_date`
- `idx_debt_payments_debt_date`
- `idx_monthly_budgets_couple_month` unique

## 5. RLS Policy Baseline

Policy pattern for tenant tables:
- Select: authenticated user must belong to row `couple_id`.
- Insert/update/delete: same membership requirement.

Membership check via `couple_members`.

## 6. Data Integrity Notes

- Soft delete only for referenced records.
- Wallet and debt remaining balances should be recalculated by reconciliation job periodically.
- Transfer creation and linked income creation should be wrapped in one transaction.
