# 📒 Family Cashbook — Product Specification

**Version:** 1.1  
**Ngày tạo:** 2026-04-16  
**Trạng thái:** Draft

---

## 1. Tổng quan sản phẩm

### 1.1 Mô tả

**Family Cashbook** là ứng dụng sổ thu chi gia đình dành cho hai vợ chồng. Thay vì phong cách "fintech" phức tạp, ứng dụng hướng đến cảm giác **quyển sổ tay gia đình số** — đơn giản, thân thiện, dễ ghi chép hàng ngày — nhưng đủ thông minh để tổng hợp, cảnh báo và tư vấn chi tiêu cho cả nhà.

### 1.2 Triết lý sản phẩm

> *"Biết tiền đi đâu, chủ động tài chính gia đình."*

- **Ghi nhanh, xem rõ** — Thêm giao dịch trong vòng 10 giây
- **Minh bạch chung** — Cả hai vợ chồng đều thấy bức tranh tài chính đầy đủ
- **Thông minh nhưng không phức tạp** — AI gợi ý, nhắc nhở đúng lúc, không spam

### 1.3 Đối tượng sử dụng

| Người dùng | Vai trò |
|---|---|
| Chồng / Vợ (User A) | Tạo tài khoản gia đình, mời người còn lại |
| Vợ / Chồng (User B) | Tham gia qua mã mời, cùng quản lý |

> Mỗi Family Cashbook chỉ có **đúng 2 thành viên**. Dữ liệu được chia sẻ hoàn toàn giữa hai người.

### 1.4 Nền tảng

- iOS (iPhone)
- Android
- PWA / Web (tùy chọn Phase 2)

---

## 2. Kiến trúc tính năng — 5 Trục chính

```
┌──────────────────────────────────────────────────────────────┐
│                      FAMILY CASHBOOK                         │
├──────────┬──────────┬──────────┬──────────┬──────────────────┤
│  Trục 1  │  Trục 2  │  Trục 3  │  Trục 4  │     Trục 5       │
│   Chi    │ Chuyển   │  Thu     │   Quỹ    │      Nợ          │
│  tiêu   │  tiền   │  nhập   │  chung   │                  │
│          │  vợ↔chồng│          │          │                  │
└──────────┴──────────┴──────────┴──────────┴──────────────────┘
```

---

## 3. Chi tiết 5 Trục chính

### 3.1 Trục 1 — Chi tiêu (Expense)

**Mô tả:** Ghi lại mọi khoản tiền chi ra của từng thành viên trong gia đình.

**Luồng thêm giao dịch:**
1. Nhấn nút "+" → Chọn "Chi tiêu"
2. Chọn danh mục (Category)
3. Nhập số tiền
4. Nhập mô tả *(tùy chọn)*
5. Chọn ngày *(mặc định: hôm nay)*
6. Xác nhận → Lưu & đồng bộ sang thiết bị kia

**Data model — Expense:**

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `id` | UUID | ✅ | |
| `user_id` | UUID | ✅ | Ai chi |
| `category_id` | UUID | ✅ | Danh mục |
| `amount` | Decimal | ✅ | Số tiền |
| `description` | String | ❌ | Ghi chú |
| `date` | Date | ✅ | Ngày giao dịch |
| `created_at` | Timestamp | ✅ | |
| `updated_at` | Timestamp | ✅ | |

**Master data — Danh mục chi tiêu (Category):**

| Trường | Kiểu | Mô tả |
|---|---|---|
| `id` | UUID | |
| `name` | String | Tên danh mục |
| `icon` | String | Emoji/icon |
| `color` | String | Mã màu HEX |
| `budget_limit` | Decimal | Ngân sách tháng cho danh mục *(tùy chọn)* |
| `is_active` | Boolean | Hiển thị/ẩn |

**Danh mục mặc định:**
🍜 Ăn uống · 🏠 Nhà cửa · 🚗 Đi lại · 💊 Sức khỏe · 👗 Mua sắm · 🎮 Giải trí · 📚 Học phí · ⚡ Tiện ích · 👶 Con cái · 🐾 Thú cưng · 📦 Khác

---

### 3.2 Trục 2 — Chuyển tiền nội bộ (Internal Transfer)

**Mô tả:** Ghi lại các lần một người chuyển tiền cho người kia (vd: chồng đưa tiền chợ, vợ chuyển tiền điện). Tự động tạo bản ghi Thu nhập bên người nhận.

**Luồng:**
1. Nhấn "+" → Chọn "Chuyển cho vợ/chồng"
2. Nhập số tiền
3. Nhập lý do *(tùy chọn — vd: "Tiền chợ tuần này")*
4. Xác nhận → Tạo Transfer + tự động tạo Income liên kết bên người nhận

**Data model — Transfer:**

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `id` | UUID | ✅ | |
| `from_user_id` | UUID | ✅ | Người chuyển |
| `to_user_id` | UUID | ✅ | Người nhận |
| `amount` | Decimal | ✅ | |
| `note` | String | ❌ | Lý do chuyển |
| `linked_income_id` | UUID | ✅ | ID Income tự động tạo |
| `date` | Date | ✅ | |
| `created_at` | Timestamp | ✅ | |

---

### 3.3 Trục 3 — Thu nhập (Income)

**Mô tả:** Ghi lại mọi nguồn tiền vào — lương, thưởng, đầu tư, hoặc nhận từ người kia (tự động từ Trục 2).

**Luồng thêm thu nhập thủ công:**
1. Nhấn "+" → Chọn "Thu nhập"
2. Chọn nguồn thu (Income Source)
3. Nhập số tiền
4. Nhập mô tả *(tùy chọn)*
5. Chọn ngày
6. Xác nhận

> Giao dịch **nhận từ chuyển khoản nội bộ** được tạo tự động và có nhãn riêng, user không thể tự tạo loại này.

**Data model — Income:**

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `id` | UUID | ✅ | |
| `user_id` | UUID | ✅ | Người nhận |
| `income_source_id` | UUID | ✅ | Nguồn thu |
| `amount` | Decimal | ✅ | |
| `description` | String | ❌ | |
| `is_from_transfer` | Boolean | ✅ | Tự động từ Trục 2? |
| `linked_transfer_id` | UUID | ❌ | Nếu là auto-generated |
| `date` | Date | ✅ | |
| `created_at` | Timestamp | ✅ | |

**Master data — Nguồn thu nhập (Income Source):**

| Trường | Kiểu | Mô tả |
|---|---|---|
| `id` | UUID | |
| `name` | String | Vd: Lương, Freelance |
| `icon` | String | |
| `type` | Enum | `salary` / `investment` / `bonus` / `other` |
| `is_active` | Boolean | |

**Nguồn mặc định:** 💼 Lương · 🎁 Thưởng · 📈 Đầu tư · 💻 Freelance · 🏘️ Cho thuê · 🎀 Quà/biếu · 📦 Khác

---

### 3.4 Trục 4 — Quỹ gia đình (Family Fund)

**Mô tả:** Hai vợ chồng cùng góp tiền vào các quỹ chung với mục tiêu rõ ràng. Theo dõi tiến độ đến khi đạt mục tiêu.

**Luồng gửi quỹ:**
1. Nhấn "+" → Chọn "Gửi vào quỹ"
2. Chọn quỹ
3. Nhập số tiền
4. Nhập ghi chú *(tùy chọn)*
5. Xác nhận

**Data model — Fund Contribution:**

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `id` | UUID | ✅ | |
| `user_id` | UUID | ✅ | Ai gửi |
| `fund_id` | UUID | ✅ | Quỹ nhận |
| `amount` | Decimal | ✅ | |
| `note` | String | ❌ | |
| `date` | Date | ✅ | |
| `created_at` | Timestamp | ✅ | |

**Master data — Quỹ gia đình (Fund):**

| Trường | Kiểu | Mô tả |
|---|---|---|
| `id` | UUID | |
| `name` | String | Vd: Quỹ du lịch, Quỹ mua nhà |
| `icon` | String | |
| `target_amount` | Decimal | Mục tiêu (tùy chọn) |
| `current_amount` | Decimal | Tổng đã góp (tự tính) |
| `deadline` | Date | Hạn đạt mục tiêu *(tùy chọn)* |
| `color` | String | Mã màu |
| `is_active` | Boolean | |

**Quỹ mặc định gợi ý:** 🆘 Khẩn cấp · ✈️ Du lịch · 🏠 Mua nhà/sửa nhà · 🎓 Học phí con · 🎄 Tết/Lễ

---

### 3.5 Trục 5 — Nợ (Debt)

**Mô tả:** Quản lý các khoản nợ bên ngoài của từng thành viên. Theo dõi tiến trình trả nợ và cảnh báo khi đến hạn.

**Data model — Debt (Khoản nợ):**

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `id` | UUID | ✅ | |
| `user_id` | UUID | ✅ | Người đang nợ |
| `debt_type_id` | UUID | ✅ | Loại nợ |
| `name` | String | ✅ | Tên khoản nợ |
| `original_amount` | Decimal | ✅ | Số tiền gốc |
| `remaining_amount` | Decimal | ✅ | Còn lại (tự tính) |
| `creditor_name` | String | ✅ | Tên người/nơi cho vay |
| `start_date` | Date | ✅ | |
| `due_date` | Date | ❌ | Hạn trả |
| `reminder_days_before` | Integer | ❌ | Nhắc trước bao nhiêu ngày |
| `note` | String | ❌ | |
| `is_closed` | Boolean | ✅ | Đã trả xong |
| `created_at` | Timestamp | ✅ | |

**Data model — Debt Payment (Lần trả nợ):**

| Trường | Kiểu | Bắt buộc | Mô tả |
|---|---|---|---|
| `id` | UUID | ✅ | |
| `debt_id` | UUID | ✅ | |
| `amount` | Decimal | ✅ | |
| `date` | Date | ✅ | |
| `note` | String | ❌ | |
| `created_at` | Timestamp | ✅ | |

**Master data — Loại nợ (Debt Type):** 🏦 Vay ngân hàng · 👤 Vay cá nhân · 💳 Thẻ tín dụng · 🏢 Vay công ty · 📦 Khác

---

## 4. Master Data Management

Tất cả master data **chia sẻ giữa 2 thành viên**, cả hai đều có quyền CRUD.

| # | Master Data | Trục liên quan |
|---|---|---|
| 1 | Danh mục chi tiêu (Category) | Trục 1 |
| 2 | Nguồn thu nhập (Income Source) | Trục 3 |
| 3 | Quỹ gia đình (Fund) | Trục 4 |
| 4 | Loại nợ (Debt Type) | Trục 5 |

**Quy tắc:**
- Không xóa cứng nếu đã có giao dịch → chỉ ẩn (`is_active = false`)
- Dữ liệu mặc định được seed khi khởi tạo gia đình

---

## 5. Dashboard & Thống kê

### 5.1 Home — Tổng quan gia đình

- Số dư ước tính tháng này (Tổng thu − Tổng chi)
- Tổng chi tiêu hôm nay / tuần này / tháng này
- Cảnh báo ngân sách danh mục sắp vượt
- Feed giao dịch gần nhất của cả hai
- Quick-add: Thêm chi tiêu ngay từ màn home

### 5.2 Thống kê Trục 1 — Chi tiêu

- **Donut chart:** Tỉ lệ chi theo danh mục trong tháng
- **Bar chart:** Tổng chi theo tháng (6 tháng gần nhất)
- **Stacked bar:** Chi tiêu của vợ vs chồng theo tháng
- So sánh với tháng trước (% tăng/giảm)
- Top 3 danh mục chi nhiều nhất

### 5.3 Thống kê Trục 3 — Thu nhập

- **Bar chart:** Thu nhập theo nguồn, theo tháng
- So sánh thu nhập vợ vs chồng
- Tổng thu nhập gia đình theo năm

### 5.4 Thống kê Trục 4 — Quỹ

- **Progress bar:** Tiến độ từng quỹ so với mục tiêu
- Lịch sử góp quỹ theo thành viên
- Dự đoán ngày đạt mục tiêu dựa trên tốc độ góp hiện tại

### 5.5 Thống kê Trục 5 — Nợ

- **Horizontal bar:** Đã trả / Còn lại của từng khoản nợ
- Tổng dư nợ gia đình
- Timeline lịch sử trả nợ

---

## 6. ✨ Tính năng AI & Thông minh

> Đây là lớp tính năng tạo sự khác biệt — ứng dụng không chỉ ghi chép mà còn **hiểu** và **đồng hành** cùng gia đình.

### 6.1 AI Phân tích chi tiêu (Spending Insights)

**Mô tả:** Cuối tuần hoặc cuối tháng, AI tổng hợp chi tiêu và đưa ra nhận xét ngắn gọn, thân thiện.

**Ví dụ output:**
> *"Tháng này gia đình chi 4.2 triệu cho Ăn uống — tăng 18% so với tháng trước. Danh mục Giải trí đang chiếm 22% tổng chi tiêu, cao hơn mức trung bình 3 tháng gần nhất."*

**Tính năng chi tiết:**
- Phát hiện danh mục chi tăng đột biến so với trung bình
- Nhận xét tuần / tháng tự động (push notification + in-app card)
- So sánh chi tiêu tháng này vs tháng trước vs trung bình 3 tháng
- Gợi ý: *"Nếu cắt giảm 500k/tháng ở Giải trí, quỹ Du lịch sẽ đạt mục tiêu sớm hơn 2 tháng"*

### 6.2 AI Phân loại giao dịch tự động (Auto-categorize)

**Mô tả:** Khi user nhập mô tả giao dịch, AI tự động gợi ý danh mục phù hợp.

**Ví dụ:**
- Gõ "Grab Food" → gợi ý 🍜 Ăn uống
- Gõ "học phí bé An" → gợi ý 👶 Con cái
- Gõ "tiền điện tháng 4" → gợi ý ⚡ Tiện ích

**Học theo thói quen:** Càng dùng càng chính xác vì học theo lịch sử giao dịch của gia đình.

### 6.3 Nhắc nhở trả nợ thông minh (Smart Debt Reminder)

**Mô tả:** Hệ thống tự động gửi thông báo nhắc nhở dựa trên `due_date` và `reminder_days_before` của từng khoản nợ.

**Cơ chế:**
- Nhắc trước N ngày (do user cấu hình, mặc định: 7 ngày và 1 ngày)
- Nếu đến hạn chưa trả → nhắc lại hàng ngày
- Push notification kèm nút "Ghi nhận đã trả" nhanh

**Ví dụ thông báo:**
> *"⏰ Khoản vay ngân hàng ACB còn 7 ngày nữa đến hạn. Còn lại: 2.5 triệu đồng."*

### 6.4 Cảnh báo vượt ngân sách (Budget Alert)

**Mô tả:** Mỗi danh mục có thể thiết lập ngân sách tháng. Khi chi tiêu sắp chạm hoặc vượt ngưỡng, app gửi cảnh báo.

**Ngưỡng cảnh báo:**
- 80% ngân sách → Thông báo nhẹ: *"Ăn uống đã dùng 80% ngân sách tháng"*
- 100% vượt → Cảnh báo đỏ: *"Đã vượt ngân sách Mua sắm 350k"*

### 6.5 Dự báo chi tiêu cuối tháng (Spending Forecast)

**Mô tả:** Dựa trên chi tiêu hiện tại và patterns lịch sử, AI dự báo tổng chi tiêu đến cuối tháng.

**Ví dụ:**
> *"Với tốc độ hiện tại, gia đình sẽ chi khoảng 12.8 triệu tháng này — cao hơn tháng trước 1.2 triệu."*

### 6.6 Gợi ý tiết kiệm định kỳ (Saving Suggestion)

**Mô tả:** Cuối tháng, nếu thu > chi, AI gợi ý phân bổ phần dư vào quỹ phù hợp.

**Ví dụ:**
> *"Tháng này gia đình dư 3.2 triệu 🎉. Gợi ý: Gửi 2 triệu vào Quỹ khẩn cấp (đang đạt 60% mục tiêu) và 1.2 triệu vào Quỹ du lịch?"*

### 6.7 Báo cáo tài chính định kỳ (Monthly Report)

**Mô tả:** Đầu tháng, gửi bản tóm tắt tháng trước dưới dạng "báo cáo gia đình" trực quan.

**Nội dung:**
- Tổng thu / chi / tiết kiệm
- Danh mục chi nhiều nhất
- Khoản nợ đã trả trong tháng
- Tiến độ quỹ thay đổi thế nào
- Điểm nổi bật và lời khuyên ngắn

---

## 7. Thông báo (Notification System)

| Loại thông báo | Trigger | Ưu tiên |
|---|---|---|
| Giao dịch mới từ người kia | Vợ/chồng vừa thêm giao dịch | Thấp (tùy chọn tắt) |
| Cảnh báo 80% ngân sách | Tiêu đến 80% budget category | Trung bình |
| Cảnh báo vượt ngân sách | Chi vượt budget | Cao |
| Nhắc trả nợ | N ngày trước due_date | Cao |
| Nợ quá hạn | Sau due_date chưa đóng | Rất cao |
| Gợi ý tiết kiệm cuối tháng | Ngày cuối tháng | Thấp |
| Báo cáo tháng | Ngày 1 đầu tháng | Trung bình |
| Quỹ đạt mục tiêu | current_amount ≥ target_amount | Cao (celebratory) |

---

## 8. Quản lý tài khoản

### 8.1 Onboarding & Liên kết

1. User A đăng ký (tên, email, mật khẩu)
2. Đặt tên gia đình (vd: "Nhà Minh - Lan")
3. Chọn đơn vị tiền tệ và ngôn ngữ
4. Nhận mã mời 6 số hoặc link mời
5. User B đăng ký → nhập mã mời → liên kết thành công
6. Seed dữ liệu mặc định (categories, income sources...)

### 8.2 Hồ sơ người dùng

| Trường | Mô tả |
|---|---|
| `display_name` | Tên hiển thị (vd: "Anh", "Em", hoặc tên thật) |
| `role_label` | Nhãn tùy chỉnh: Chồng / Vợ / Bố / Mẹ |
| `avatar` | Ảnh đại diện |
| `email` | Email đăng nhập |

### 8.3 Bảo mật

- Đăng nhập email/password
- Hỗ trợ Face ID / Touch ID
- JWT + Refresh token
- Tùy chọn: PIN 4 số khi mở app

---

## 9. Cài đặt gia đình (Family Settings)

| Tính năng | Mô tả |
|---|---|
| Tên gia đình | Hiển thị trên app |
| Đơn vị tiền tệ | VND, USD, ... |
| Ngôn ngữ | Tiếng Việt, English |
| Thông báo | Bật/tắt từng loại |
| Ngân sách tháng | Tổng ngân sách gia đình |
| Export dữ liệu | Xuất CSV/Excel theo khoảng thời gian |
| Backup | Cloud backup tự động |

---

## 10. Sơ đồ màn hình (Screen Map)

```
App
├── Onboarding
│   ├── Màn chào
│   ├── Đăng ký / Đăng nhập
│   ├── Tạo gia đình / Tham gia gia đình
│   └── Setup ban đầu (tiền tệ, ngân sách...)
│
├── Home (Dashboard tổng quan)
│   ├── Số dư & tổng quan tháng
│   ├── AI Insight card
│   ├── Cảnh báo ngân sách / nợ
│   └── Feed giao dịch gần nhất
│
├── Sổ giao dịch (Transaction Feed)
│   ├── Danh sách tất cả (lọc theo trục / người / tháng)
│   └── Chi tiết giao dịch
│
├── Thêm giao dịch (+)
│   ├── Chi tiêu (Trục 1)
│   ├── Chuyển tiền (Trục 2)
│   ├── Thu nhập (Trục 3)
│   ├── Gửi quỹ (Trục 4)
│   └── Trả nợ (Trục 5)
│
├── Thống kê
│   ├── Tổng quan thu/chi
│   ├── Chi tiêu theo danh mục
│   ├── Thu nhập
│   └── Báo cáo tháng (AI)
│
├── Quỹ gia đình
│   ├── Danh sách quỹ + tiến độ
│   ├── Chi tiết quỹ
│   └── Lịch sử đóng góp
│
├── Nợ
│   ├── Danh sách khoản nợ
│   ├── Chi tiết + lịch sử trả
│   └── Thêm khoản nợ
│
├── Danh mục (Master Data)
│   ├── Danh mục chi tiêu
│   ├── Nguồn thu nhập
│   ├── Quỹ (config)
│   └── Loại nợ
│
└── Cài đặt
    ├── Hồ sơ cá nhân
    ├── Cài đặt gia đình
    ├── Thông báo
    ├── Ngân sách danh mục
    └── Export / Backup
```

---

## 11. Phi chức năng (Non-functional Requirements)

| Tiêu chí | Yêu cầu |
|---|---|
| Tốc độ thêm giao dịch | ≤ 3 tap, ≤ 10 giây |
| Load màn hình chính | < 1 giây |
| Đồng bộ giữa 2 thiết bị | < 3 giây (real-time) |
| Hỗ trợ offline | Ghi giao dịch offline, sync khi có mạng |
| Bảo mật | HTTPS/TLS, mã hóa dữ liệu nhạy cảm at-rest |
| Uptime | ≥ 99.5% |
| Dữ liệu | Lưu trữ không giới hạn, hỗ trợ 5+ năm dữ liệu |

---

## 12. Tech Stack gợi ý

### Mobile
- **Flutter** — Cross-platform iOS + Android, hiệu năng cao, UI mượt

### Backend
- **Node.js (NestJS)** hoặc **Supabase** (BaaS — nhanh hơn cho MVP)
- REST API + WebSocket cho real-time sync
- **PostgreSQL** — phù hợp dữ liệu tài chính có quan hệ

### AI Features
- **Anthropic Claude API** — Phân tích chi tiêu, tạo insight, gợi ý ngôn ngữ tự nhiên
- Rule-based engine cho auto-categorize (Phase 1) → ML model (Phase 2)

### Infrastructure
- Firebase Auth + FCM (push notification)
- Cloud Storage (avatar)
- AWS / GCP / Supabase hosting

---

## 13. Roadmap phát triển

### Phase 1 — MVP (Sổ tay số)
- [ ] Onboarding, đăng ký, liên kết gia đình
- [ ] CRUD 4 master data
- [ ] Trục 1: Chi tiêu
- [ ] Trục 3: Thu nhập thủ công
- [ ] Trục 4: Quỹ gia đình
- [ ] Dashboard cơ bản
- [ ] Sync real-time 2 thiết bị

### Phase 2 — Core Complete
- [ ] Trục 2: Chuyển tiền nội bộ + auto-link
- [ ] Trục 5: Nợ + lịch sử trả nợ
- [ ] Ngân sách danh mục + cảnh báo
- [ ] Thống kê đầy đủ 5 trục
- [ ] Push notification cơ bản (nhắc nợ, vượt ngân sách)
- [ ] Export CSV/Excel

### Phase 3 — AI & Intelligence
- [ ] AI Spending Insights (cuối tuần/tháng)
- [ ] Auto-categorize gợi ý danh mục
- [ ] Smart Debt Reminder
- [ ] Spending Forecast cuối tháng
- [ ] Monthly Report tự động
- [ ] Gợi ý phân bổ tiền dư vào quỹ

### Phase 4 — Polish & Growth
- [ ] Widget iOS/Android (quick-add + số dư)
- [ ] Dark mode
- [ ] Backup & restore
- [ ] Recurring transaction (giao dịch định kỳ)
- [ ] Scan hóa đơn bằng camera

---

*Tài liệu nội bộ — Family Cashbook Product Spec v1.1*  
*Cập nhật khi có thay đổi yêu cầu.*