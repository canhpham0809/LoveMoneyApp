# System Overview - Family Cashbook

## 1. Architecture

### Client layer
- Flutter mobile app (iOS and Android).
- Optional web client in later phase.

### Backend layer
- Supabase-based stack for MVP:
	- Postgres database.
	- Auth.
	- Realtime sync.
	- Storage for avatars.
- Optional domain service layer (Node/NestJS) for advanced logic.

### Integration layer
- Push notifications via FCM/APNs.
- AI provider integration for advanced insights.

## 2. Core Domain Modules

- Identity and family linking.
- Wallet and balance engine.
- Transactions:
	- Expense
	- Income
	- Internal transfer
	- Fund contribution
	- Debt payment
- Master data.
- Budget and alerts.
- Analytics.
- AI intelligence.

## 3. Data Flow (Write Path)

1. Client submits transaction request.
2. Backend validates ownership and couple scope.
3. Transaction row is written.
4. Balance and denormalized fields update in same logical unit.
5. Realtime event emitted to both members.
6. Notification pipeline evaluates trigger conditions.

## 4. Data Flow (Read Path)

1. Client loads dashboard summary endpoints.
2. Backend returns denormalized aggregates.
3. Feed requests paginate by date window.
4. Client subscribes to realtime updates.

## 5. Multi-tenant and Security Model

- Every row belongs to one `couple_id`.
- Access governed by row-level security.
- Two linked members share same family scope.
- Cross-family read/write is denied.

## 6. Offline and Sync Strategy

- Client queues writes when offline.
- Queue retries when connectivity restores.
- Conflict strategy:
	- deterministic last-write-wins for editable fields
	- audit trail retained via `updated_by` and `updated_at`

## 7. Performance Strategy

- Denormalize read-heavy fields (example: category name/icon on expense).
- Maintain wallet balances as denormalized values.
- Apply indexes on high-selectivity filters.
- Reconciliation job validates wallet balance integrity.

## 8. Reliability Targets

- Home load target: under 1 second.
- Write-to-sync visibility target: under 3 seconds typical.
- Availability target: 99.5 percent or higher.
