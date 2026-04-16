# Status Audit - Family Cashbook v2

Ngay cap nhat: 2026-04-16
Nguon doi chieu:
- [docs/spec/family_cashbook_spect_v2.md](docs/spec/family_cashbook_spect_v2.md)
- Toan bo tai lieu trong [docs](docs)
- Code Flutter trong [lib](lib)
- Migration Supabase trong [supabase/migrations](supabase/migrations)

## 1) Tom tat nhanh

- He thong da co nen tang schema + governance kha day du (RLS, soft delete, audit, couple isolation).
- App da chay duoc nhom flow co ban: auth, tao/join couple, expense, income, dashboard tong quan.
- Nhieu yeu cau quan trong trong spec v2 chua dat: Quick Add + Undo, AI Safe Mode + AI insights, Notification, budget alerts, transfer auto-link income.

Danh gia tong quan:
- Coverage ve data architecture/governance: ~90%
- Coverage ve user-facing feature flow theo spec v2: ~45%
- Coverage tong hop hien tai: ~55%

## 2) Cac muc da lam (Implemented)

### 2.1 Nen tang du lieu va bao mat
- Da tao day du core tables theo huong v2: wallet, expense, income, transfer, fund, debt, budget, master data.
- Da co RLS theo couple_id, chong truy cap cross-family.
- Da co audit columns, soft delete, updated_by trigger, updated_at trigger.
- Da co view tinh so du vi wallet_balances.

Bang chung:
- [supabase/migrations/20260416_000001_family_cashbook_schema.sql](supabase/migrations/20260416_000001_family_cashbook_schema.sql)

### 2.2 Onboarding va family linking
- Dang ky/dang nhap Supabase Auth.
- Tao couple.
- Join couple bang invite code qua RPC.
- Copy invite code trong Settings.

Bang chung:
- [lib/features/auth/presentation/screens/login_screen.dart](lib/features/auth/presentation/screens/login_screen.dart)
- [lib/features/settings/presentation/screens/create_couple_screen.dart](lib/features/settings/presentation/screens/create_couple_screen.dart)
- [lib/features/settings/presentation/screens/join_couple_screen.dart](lib/features/settings/presentation/screens/join_couple_screen.dart)
- [lib/features/settings/presentation/screens/settings_screen.dart](lib/features/settings/presentation/screens/settings_screen.dart)
- [supabase/migrations/20260416_000002_couple_invite_code_and_join_rpc.sql](supabase/migrations/20260416_000002_couple_invite_code_and_join_rpc.sql)

### 2.3 Core giao dich co ban
- Expense: list, add, soft delete.
- Income: list, add, soft delete (service).
- Transfer: list, add, soft delete (service).
- Dashboard: tong so du, thu/chi thang, recent transactions.
- Analytics co ban: expense theo category (thang hien tai).

Bang chung:
- [lib/features/expense/data/services/expense_service.dart](lib/features/expense/data/services/expense_service.dart)
- [lib/features/expense/presentation/screens/expense_list_screen.dart](lib/features/expense/presentation/screens/expense_list_screen.dart)
- [lib/features/income/data/services/income_service.dart](lib/features/income/data/services/income_service.dart)
- [lib/features/income/presentation/screens/income_list_screen.dart](lib/features/income/presentation/screens/income_list_screen.dart)
- [lib/features/transfer/data/services/transfer_service.dart](lib/features/transfer/data/services/transfer_service.dart)
- [lib/features/transfer/presentation/screens/transfer_list_screen.dart](lib/features/transfer/presentation/screens/transfer_list_screen.dart)
- [lib/features/dashboard/data/services/dashboard_service.dart](lib/features/dashboard/data/services/dashboard_service.dart)
- [lib/features/dashboard/presentation/screens/dashboard_screen.dart](lib/features/dashboard/presentation/screens/dashboard_screen.dart)

## 3) Doi chieu coverage theo Pillar/Module (spec v2)

| Module | Trang thai | Coverage uoc tinh | Ghi chu |
|---|---|---:|---|
| Wallet & Balance | Partial | 60% | Da co table/service/view, nhung UI wallet chua duoc noi vao app shell va add wallet chua hoan thien. |
| Expense | Partial | 70% | Add/list/delete co, chua co edit/duplicate/search/undo/quick add. |
| Internal Transfer | Partial (gap nghiem trong) | 35% | Co UI/service tao transfer, nhung chua auto tao linked income; hien tai UI set from_user = to_user de gay fail voi DB constraint. |
| Income | Partial | 65% | Add/list co, chua co edit/delete tu UI, chua lien ket transfer tu dong. |
| Family Fund | Partial | 25% | Co service, list screen, nhung add fund UI dang placeholder va chua noi flow contribution day du tren UI. |
| Debt | Partial | 25% | Co service/list, add debt UI placeholder, chua co debt payment flow UI/reminder. |
| Monthly Budget | Partial | 20% | Co schema/field settings, chua co man hinh quan ly monthly_budgets va alerts 80/100%. |
| Category Budget | Not implemented | 5% | Moi co cot budget_limit trong category, chua co logic canh bao. |
| Dashboard/Analytics | Partial | 50% | Co summary co ban va breakdown category, chua day du analytics theo pillars + debt/fund alerts. |
| Quick Add + Undo | Not implemented | 0% | Chua co parser 50k/1tr, chua co snackbar undo atomically restore. |
| AI Safe Mode + AI features | Not implemented | 0% | Chua co gating 30 transactions/14 days, chua co insights/forecast/report. |
| Notifications | Not implemented | 0% | Chua co trigger engine + push integration. |
| Search/Export | Not implemented | 0% | Chua co transaction search/filter/export CSV/Excel. |
| Governance/RLS | Implemented | 90% | RLS + soft delete + audit da co kha day du. |

## 4) Cac lech chinh giua code va tai lieu

1. Transfer chua dung business rule v2.
- Spec yeu cau transfer phai auto tao income linked cho nguoi nhan.
- Code hien tai chi insert transfer.
- UI add transfer dang set from_user_id va to_user_id cung user hien tai.
- DB co constraint from_user_id <> to_user_id nen flow de loi.

Bang chung:
- [docs/01-product/product_requirements.md](docs/01-product/product_requirements.md)
- [lib/features/transfer/presentation/screens/add_transfer_screen.dart](lib/features/transfer/presentation/screens/add_transfer_screen.dart)
- [lib/features/transfer/data/services/transfer_service.dart](lib/features/transfer/data/services/transfer_service.dart)
- [supabase/migrations/20260416_000001_family_cashbook_schema.sql](supabase/migrations/20260416_000001_family_cashbook_schema.sql)

2. Quick Add/Undo chua co.

Bang chung:
- [docs/01-product/feature_specs/quick_add_and_undo.md](docs/01-product/feature_specs/quick_add_and_undo.md)
- [docs/spec/family_cashbook_spect_v2.md](docs/spec/family_cashbook_spect_v2.md)

3. AI va Notification chua co.

Bang chung:
- [docs/01-product/feature_specs/ai_and_notification_system.md](docs/01-product/feature_specs/ai_and_notification_system.md)
- [docs/spec/family_cashbook_spect_v2.md](docs/spec/family_cashbook_spect_v2.md)

4. Fund/Debt/Wallet UI chua hoan tat va chua expose day du tren shell.

Bang chung:
- [lib/features/fund/presentation/screens/fund_list_screen.dart](lib/features/fund/presentation/screens/fund_list_screen.dart)
- [lib/features/debt/presentation/screens/debt_list_screen.dart](lib/features/debt/presentation/screens/debt_list_screen.dart)
- [lib/features/wallet/presentation/screens/wallet_list_screen.dart](lib/features/wallet/presentation/screens/wallet_list_screen.dart)
- [lib/features/shared/presentation/screens/app_shell_screen.dart](lib/features/shared/presentation/screens/app_shell_screen.dart)

5. Test coverage thap so voi test plan.
- Hien tai chu yeu 1 widget test login gate.

Bang chung:
- [test/widget_test.dart](test/widget_test.dart)
- [docs/04-quality/test_plan.md](docs/04-quality/test_plan.md)

## 5) Du dinh se lam (recommended roadmap)

### Uu tien P0 (can lam ngay)
1. Sua transfer flow dung rule.
- Chon from_user/to_user dung 2 thanh vien trong couple.
- Tao linked income transactionally.
- Dam bao cap nhat wallet balance logic dong nhat.

2. Mo khoa UI cho Wallet/Fund/Debt.
- Noi route vao shell.
- Hoan tat add/edit/delete thay vi placeholder.

3. Them undo cho create/update/delete transaction.
- Snackbar 3-5s + restore atomically.

### Uu tien P1
1. Monthly budget + category budget threshold.
- Tinh progress.
- Canh bao 80%/100%.

2. Search/filter/export.
- Loc theo date/category/member/wallet.
- Export CSV/Excel.

3. Debt payment full flow + reminder scheduler.

### Uu tien P2
1. Quick Add parser (k, tr, number literal) + fallback full form.
2. AI Safe Mode gate (>=30 tx hoac >=14 ngay active).
3. Rule-based insight card truoc, sau do tich hop Claude API theo phase 3.

## 6) Luu y bo sung trong code hien tai

- Co file cu [lib/features/services/transaction_service.dart](lib/features/services/transaction_service.dart) thao tac bang transactions table khong ton tai trong schema moi. Nen xem lai de tranh gay nham/tech debt.
- Settings model cu co fields notifications_enabled/biometric_enabled nhung service hien tai dang dung couples table theo shape khac. Can dong bo model de tranh runtime issue neu duoc dung lai.

Bang chung:
- [lib/features/services/transaction_service.dart](lib/features/services/transaction_service.dart)
- [lib/features/settings/data/models/settings_model.dart](lib/features/settings/data/models/settings_model.dart)
- [lib/features/settings/data/services/settings_service.dart](lib/features/settings/data/services/settings_service.dart)
