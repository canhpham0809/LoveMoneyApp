# Family Cashbook - Changelog

## v2.0.0 - 2026-04-16

Initial full documentation set generated from spec v2.

### Added
- Full product, engineering, QA, and guide documentation structure.
- Feature specs for all core features.
- Test cases for all core features.

### Product upgrades reflected
- Wallet and Balance promoted to core pillar.
- Monthly family budget added alongside category budget.
- Quick Add and Undo flow documented as core UX.
- AI Safe Mode gating and rollout strategy documented.

### Engineering upgrades reflected
- Mandatory governance columns for core tables:
	- `couple_id`
	- `updated_at`, `updated_by`
	- `is_deleted`, `deleted_at`
- RLS and tenancy isolation clarified.
- Offline queue and sync conflict handling documented.

## v1.1.0 - 2026-04-16

Baseline Family Cashbook specification drafted.
