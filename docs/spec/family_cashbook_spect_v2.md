# Family Cashbook - Product Specification v2.0

Version: 2.0  
Date: 2026-04-16  
Status: Draft (Integrated v1.1 + v1.2 upgrade)

---

## 0. Change Summary (v2.0)

This v2 document consolidates:
- Baseline structure and business scope from v1.1
- Major upgrades from v1.2 (wallet/balance-first, quick add, monthly budget, data governance hardening)

Major additions in v2:
- Wallet and balance system as core domain (not optional)
- Common data governance fields for all core tables (`couple_id`, audit, soft delete)
- Monthly family budget (global) in addition to category budget (per-category)
- Quick Add UX (natural amount parsing + undo)
- AI Safe Mode gating before advanced AI features
- More concrete non-functional targets and phased rollout

---

## 1. Product Overview

### 1.1 Product Description

Family Cashbook is a household cashbook app for couples. The product direction is not a complex fintech dashboard, but a digital family notebook: fast to log, easy to read, shared transparently by both members, and smart enough to support better financial decisions.

### 1.2 Product Philosophy

"Log as fast as writing a notebook, review as clear as a monthly summary."

Core principles:
- Fast capture first: users should log transactions in seconds
- Balance-first: always answer "How much money do we have now?"
- Shared transparency: both members see a complete and consistent picture
- Helpful AI, not noisy AI: contextual suggestions, gated by data sufficiency

### 1.3 Target Users

| User | Role |
|---|---|
| User A | Creates family space and invites partner |
| User B | Joins via invite code/link and co-manages data |

Business rule:
- One family has exactly 2 members
- Family financial data is shared by default

### 1.4 Platforms

- iOS (Flutter)
- Android (Flutter)
- Web/PWA (Phase 2+)

---

## 2. Functional Architecture

Family Cashbook v2 consists of 6 functional pillars:
- Pillar 0: Wallet and Balance (new core)
- Pillar 1: Expense
- Pillar 2: Internal Transfer (between spouses)
- Pillar 3: Income
- Pillar 4: Family Fund
- Pillar 5: Debt

Supporting modules:
- Master Data Management
- Dashboard and Analytics
- Notification System
- AI and Intelligence Layer
- Account, Family Settings, Security

---

## 3. Pillar 0 - Wallet and Balance (Core in v2)

### 3.1 Goal

Always provide reliable answer to:
- Current family balance
- Balance by wallet/account
- How each transaction changes available money

### 3.2 Wallet modes

- Default mode (MVP): one wallet `Family Cash`
- Advanced mode: multi-wallet (cash, bank accounts, e-wallets)

### 3.3 Wallet model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | Tenant isolation |
| `name` | String | Yes | Wallet name |
| `type` | Enum | Yes | `cash`, `bank`, `ewallet`, `other` |
| `balance` | Decimal | Yes | Denormalized current balance |
| `currency` | String | Yes | Default from family settings |
| `is_default` | Boolean | Yes | Default wallet |
| `is_active` | Boolean | Yes | Hide/show wallet |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | Audit |
| `is_deleted` | Boolean | Yes | Soft delete |
| `deleted_at` | Timestamp | No | Soft delete timestamp |

### 3.4 Balance update rules

- Expense: subtract from `wallet.balance`
- Income: add to `wallet.balance`
- Internal transfer: subtract from source wallet, add to destination wallet
- Fund contribution: subtract from selected wallet
- Debt payment: subtract from selected wallet

### 3.5 Consistency policy

- Primary update: transactional write on source event
- Read optimization: denormalized wallet balance
- Recovery: periodic reconciliation job for balance drift

---

## 4. Pillar 1 - Expense

### 4.1 User flow

1. Tap `+` -> select `Expense`
2. Select category
3. Enter amount
4. Enter description (optional)
5. Choose wallet
6. Choose date (default today)
7. Confirm -> save -> sync

### 4.2 Expense model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | New in v2 baseline |
| `user_id` | UUID | Yes | Who spent |
| `wallet_id` | UUID | Yes | New in v2 baseline |
| `category_id` | UUID | Yes | |
| `category_name` | String | No | Denormalized for feed performance |
| `category_icon` | String | No | Denormalized for feed performance |
| `amount` | Decimal | Yes | |
| `description` | String | No | |
| `date` | Date | Yes | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | Audit |
| `is_deleted` | Boolean | Yes | Soft delete |
| `deleted_at` | Timestamp | No | |

### 4.3 Category master

| Field | Type | Note |
|---|---|---|
| `id` | UUID | |
| `couple_id` | UUID | |
| `name` | String | Category name |
| `icon` | String | Emoji/icon |
| `color` | String | HEX |
| `budget_limit` | Decimal | Monthly per-category budget |
| `sort_order` | Integer | Display order |
| `is_active` | Boolean | Hide/show |
| `created_at` | Timestamp | |
| `updated_at` | Timestamp | |
| `updated_by` | UUID | |
| `is_deleted` | Boolean | Soft delete |
| `deleted_at` | Timestamp | |

Default categories:
- Food
- Home
- Transport
- Health
- Shopping
- Entertainment
- Education
- Utilities
- Kids
- Pets
- Other

### 4.4 Category merge

Admin/member can merge category A into B:
- Re-map all historical transactions from A -> B
- A becomes inactive (or soft-deleted)
- Preserve audit trail of merge action

---

## 5. Pillar 2 - Internal Transfer

### 5.1 Purpose

Track spouse-to-spouse transfer events transparently and keep net family accounting consistent.

### 5.2 Flow

1. Tap `+` -> `Transfer`
2. Select sender and receiver wallet
3. Enter amount and note
4. Confirm -> create transfer
5. System auto-creates linked income record for receiver

### 5.3 Transfer model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `from_user_id` | UUID | Yes | |
| `to_user_id` | UUID | Yes | |
| `from_wallet_id` | UUID | Yes | New in v2 baseline |
| `to_wallet_id` | UUID | Yes | New in v2 baseline |
| `amount` | Decimal | Yes | |
| `note` | String | No | |
| `linked_income_id` | UUID | Yes | Auto-generated relation |
| `date` | Date | Yes | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | Soft delete |
| `deleted_at` | Timestamp | No | |

Business note:
- Transfer does not change total family net worth; only wallet/member allocation.

---

## 6. Pillar 3 - Income

### 6.1 Flow (manual)

1. Tap `+` -> `Income`
2. Select source
3. Enter amount
4. Select wallet
5. Add description (optional)
6. Select date and save

### 6.2 Income model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `user_id` | UUID | Yes | Recipient |
| `wallet_id` | UUID | Yes | New in v2 baseline |
| `income_source_id` | UUID | Yes | |
| `amount` | Decimal | Yes | |
| `description` | String | No | |
| `is_from_transfer` | Boolean | Yes | Auto from transfer? |
| `linked_transfer_id` | UUID | No | If auto-generated |
| `date` | Date | Yes | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | Soft delete |
| `deleted_at` | Timestamp | No | |

### 6.3 Income source master

| Field | Type | Note |
|---|---|---|
| `id` | UUID | |
| `couple_id` | UUID | |
| `name` | String | |
| `icon` | String | |
| `type` | Enum | `salary`, `investment`, `bonus`, `freelance`, `rental`, `gift`, `other` |
| `is_active` | Boolean | |
| `created_at` | Timestamp | |
| `updated_at` | Timestamp | |
| `updated_by` | UUID | |
| `is_deleted` | Boolean | |
| `deleted_at` | Timestamp | |

Default sources:
- Salary
- Bonus
- Investment
- Freelance
- Rental
- Gift
- Other

---

## 7. Pillar 4 - Family Fund

### 7.1 Purpose

Enable shared savings goals with progress tracking.

### 7.2 Fund model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `name` | String | Yes | |
| `icon` | String | No | |
| `target_amount` | Decimal | No | Goal amount |
| `current_amount` | Decimal | Yes | Denormalized |
| `deadline` | Date | No | |
| `color` | String | No | |
| `is_active` | Boolean | Yes | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | |
| `deleted_at` | Timestamp | No | |

### 7.3 Fund contribution model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `user_id` | UUID | Yes | Contributor |
| `fund_id` | UUID | Yes | |
| `wallet_id` | UUID | Yes | New in v2 baseline |
| `amount` | Decimal | Yes | |
| `note` | String | No | |
| `date` | Date | Yes | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | |
| `deleted_at` | Timestamp | No | |

Default funds:
- Emergency
- Travel
- House
- Kids education
- Holiday

---

## 8. Pillar 5 - Debt

### 8.1 Debt model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `user_id` | UUID | Yes | Debtor |
| `debt_type_id` | UUID | Yes | |
| `name` | String | Yes | Debt name |
| `original_amount` | Decimal | Yes | |
| `remaining_amount` | Decimal | Yes | Denormalized |
| `creditor_name` | String | Yes | |
| `start_date` | Date | Yes | |
| `due_date` | Date | No | |
| `reminder_days_before` | Integer | No | |
| `note` | String | No | |
| `is_closed` | Boolean | Yes | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | |
| `deleted_at` | Timestamp | No | |

### 8.2 Debt payment model

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `debt_id` | UUID | Yes | |
| `wallet_id` | UUID | Yes | New in v2 baseline |
| `amount` | Decimal | Yes | |
| `date` | Date | Yes | |
| `note` | String | No | |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | |
| `deleted_at` | Timestamp | No | |

### 8.3 Debt type master

Default debt types:
- Bank loan
- Personal loan
- Credit card
- Company loan
- Other

---

## 9. Monthly Budget System

### 9.1 Monthly family budget (new in v2 baseline)

Model: `monthly_budgets`

| Field | Type | Required | Note |
|---|---|---|---|
| `id` | UUID | Yes | |
| `couple_id` | UUID | Yes | |
| `month` | String | Yes | Format `YYYY-MM` |
| `amount` | Decimal | Yes | Total budget for month |
| `created_at` | Timestamp | Yes | |
| `updated_at` | Timestamp | Yes | |
| `updated_by` | UUID | No | |
| `is_deleted` | Boolean | Yes | |
| `deleted_at` | Timestamp | No | |

Display examples:
- Progress: `18,000,000 / 25,000,000`
- Warning at 80%
- Critical alert at 100%+

### 9.2 Category budget

Per-category monthly budget remains active in parallel and is independent from monthly family budget.

---

## 10. Master Data Governance

Shared by both family members:
- Expense category
- Income source
- Fund
- Debt type
- Wallet (in multi-wallet mode)

Rules:
- No hard delete for referenced master data
- Prefer `is_active = false` or soft delete
- Seed default records at family creation
- CRUD permission for both members, protected by audit log

---

## 11. Dashboard and Analytics

### 11.1 Home dashboard

Must include:
- Current family balance
- This month net (`income - expense`)
- Today/week/month expense highlights
- Monthly budget progress and warning states
- Debt reminders and due warnings
- Recent transaction feed from both members
- Quick Add entry point

### 11.2 Analytics by pillar

Expense:
- Category share (donut)
- Monthly trend (bar)
- Member comparison (stacked bar)
- Month-over-month change
- Top spending categories

Income:
- Income by source and month
- Member comparison
- Yearly family income

Fund:
- Goal progress
- Contribution by member
- Estimated target completion date

Debt:
- Paid vs remaining per debt
- Total family outstanding debt
- Payment timeline

---

## 12. Quick Add, Edit, and Undo UX (v2)

### 12.1 Quick Add

Goal:
- Intent to saved in <= 2 seconds under normal conditions

Input examples:
- `50k breakfast`
- `1tr electricity`
- `200k coffee`

Parse behavior:
- Amount parsing supports `k`, `tr`, and numeric literals
- Best-effort category auto-suggestion by keyword map
- If parse fails -> open full form with prefilled text

### 12.2 Undo flow

After create/update/delete:
- Show snackbar for 3-5 seconds with `Undo`
- Undo should restore previous state atomically

### 12.3 Edit shortcuts

- Tap -> full detail edit
- Swipe -> quick edit
- Long-press -> duplicate transaction

### 12.4 Input quality

- Numeric keypad for amount fields
- Currency formatting in locale style
- Default to last-used category/wallet where appropriate
- Real-time transaction search by text/category/date

---

## 13. AI and Intelligence Layer

### 13.1 AI Safe Mode (gate)

Advanced AI is enabled only when:
- At least 30 transactions OR
- At least 14 days of active usage

Fallback UI when not eligible:
- "Continue logging to unlock spending insights"

### 13.2 AI features

1. Spending insights (weekly/monthly): trends, anomalies, category spikes
2. Auto-categorize suggestion from description text
3. Smart debt reminder based on due date and reminder config
4. End-of-month spending forecast
5. Saving suggestion for surplus allocation to funds
6. Monthly financial summary report

### 13.3 Rollout strategy

- Phase 1: rule-based insights and keyword classification
- Phase 3: Claude API integration for richer summaries/suggestions

### 13.4 AI safety and quality controls

- Confidence threshold before auto-apply category
- Explainable suggestion text (why suggested)
- User correction feedback loop for model improvement
- No AI action can bypass user-visible transaction records

---

## 14. Notification System

| Notification | Trigger | Priority |
|---|---|---|
| New transaction from partner | Real-time event | Low (toggleable) |
| Daily "no transaction yet" reminder | Daily schedule | Low |
| Weekly summary | End of week | Low |
| 80% category budget reached | Threshold | Medium |
| 100% category budget exceeded | Threshold | High |
| 80% monthly budget reached | Threshold | Medium |
| 100% monthly budget exceeded | Threshold | High |
| Debt due reminder | N days before due date | High |
| Debt overdue | After due date | Very high |
| Fund goal reached | current >= target | High (celebratory) |
| End-month saving suggestion | End of month | Low |
| Monthly report | Day 1 each month | Medium |

---

## 15. Account, Family Settings, Security

### 15.1 Onboarding

1. Register (name/email/password)
2. Create family space
3. Configure currency/language
4. Generate invite code/link
5. Partner joins and links to family
6. Seed default data

### 15.2 User profile

| Field | Description |
|---|---|
| `display_name` | Display name |
| `role_label` | Husband/Wife or custom role label |
| `avatar` | Profile image |
| `email` | Login email |

### 15.3 Family settings

- Family name
- Currency
- Language
- Notification preferences
- Monthly budget settings
- Export CSV/Excel
- Backup and restore

### 15.4 Security baseline

- Email/password authentication
- Biometric support (Face ID/Touch ID)
- JWT + refresh token lifecycle
- Optional 4-digit app PIN
- TLS/HTTPS enforced
- Encryption for sensitive at-rest data

---

## 16. Screen Map

```text
App
|- Onboarding
|  |- Welcome
|  |- Register/Login
|  |- Create/Join family
|  |- Initial setup
|
|- Home Dashboard
|  |- Family balance and monthly net
|  |- Budget progress (monthly + category alerts)
|  |- AI insight card (gated)
|  |- Debt/fund reminders
|  |- Recent transaction feed
|  |- Quick Add
|
|- Transactions
|  |- Full feed (filters by pillar/member/month/wallet)
|  |- Transaction detail
|  |- Edit/duplicate/delete + undo
|
|- Add Transaction (+)
|  |- Expense
|  |- Transfer
|  |- Income
|  |- Fund contribution
|  |- Debt payment
|
|- Funds
|  |- Fund list + progress
|  |- Fund detail
|  |- Contribution history
|
|- Debt
|  |- Debt list
|  |- Debt detail + payment history
|  |- Add debt
|
|- Analytics
|  |- Expense analytics
|  |- Income analytics
|  |- Fund analytics
|  |- Debt analytics
|  |- Monthly report
|
|- Master Data
|  |- Categories
|  |- Income sources
|  |- Funds
|  |- Debt types
|  |- Wallets
|
`- Settings
   |- Profile
   |- Family settings
   |- Notifications
   |- Budget settings
   |- Export/Backup
```

---

## 17. Data Architecture and System Rules

### 17.1 Mandatory columns in core tables

All transactional and master tables should include:
- `couple_id` for tenant isolation and RLS
- `created_at`, `updated_at`, `updated_by` for auditing
- `is_deleted`, `deleted_at` for soft delete behavior

### 17.2 Access model

- Row-level security scoped by `couple_id`
- Both members can read/write shared family records
- Cross-family access is strictly denied

### 17.3 Sync and offline

- Real-time sync between two devices (eventual consistency)
- Offline writes queued locally and replayed when network returns
- Conflict resolution by deterministic policy (last-write-wins + audit trail)

### 17.4 Performance strategy

- Denormalize read-heavy fields for feed rendering
- Index on `couple_id`, `date`, `wallet_id`, `category_id`
- Lazy-load historical records by date window

---

## 18. Non-Functional Requirements

| Metric | Target |
|---|---|
| Add transaction flow | <= 5 seconds |
| Quick Add success path | <= 2 seconds |
| Home initial load | < 1 second |
| Cross-device sync visibility | < 3 seconds typical |
| Availability | >= 99.5% |
| Offline capability | Queue + retry without data loss |
| Data retention | Supports 5+ years history |

---

## 19. Tech Stack Recommendation

Mobile:
- Flutter (iOS/Android shared codebase)

Backend:
- Supabase (PostgreSQL + realtime + auth) for MVP speed
- Optional Node/NestJS layer for advanced domain logic

AI:
- Rule-based engine in early phases
- Claude API integration in advanced AI phase

Infrastructure:
- FCM/APNs for push notifications
- Cloud storage for profile assets
- Hosted on Supabase and/or AWS/GCP as needed

---

## 20. Delivery Roadmap

### Phase 1 - MVP (Digital notebook)
- Onboarding and family linking
- Single default wallet
- Expense, Income (manual), Fund contribution
- Quick Add and Undo/Edit baseline
- Core dashboard and real-time sync
- CRUD for core master data

### Phase 2 - Core complete
- Internal transfer with auto-linked income
- Debt and debt payment flows
- Multi-wallet support
- Monthly family budget + category budget alerts
- Full analytics across pillars
- Notifications (daily/weekly/basic thresholds)
- Export CSV/Excel and search

### Phase 3 - AI intelligence
- AI spending insights (gated)
- Auto-categorize via AI enhancement
- Smart debt reminder enhancements
- Spending forecast and monthly report
- Saving suggestion and category merge workflow

### Phase 4 - Polish and growth
- iOS/Android widgets (quick add + balance)
- Recurring transactions
- Receipt scan via camera
- Backup/restore improvements
- PWA/Web expansion and UX polish

---

## 21. Acceptance Criteria (High-Level)

The spec is considered ready for engineering kickoff when:
- All pillar flows have explicit create/edit/delete behaviors
- Data model fields and mandatory governance columns are finalized
- Wallet and budget semantics are unambiguous
- AI gating and fallback UX are documented
- NFR targets are agreed by Product + Engineering
- Phase 1 scope is locked and estimable

---

## 22. Out of Scope (Current v2)

Not mandatory in immediate build unless pulled into sprint scope:
- Full accounting-grade double-entry ledger
- Investment portfolio valuation with market pricing
- OCR invoice scan in MVP
- Full desktop application

---

Internal document - Family Cashbook Spec v2.0
Update this file when product requirements change.
