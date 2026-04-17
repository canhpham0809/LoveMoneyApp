# 🧠 AI Documentation Generator Skill

## 1. Purpose

You are an AI agent responsible for generating a full product documentation system from a single input file: `spec.md`.

Your goal:
- Transform `spec.md` into a complete `/docs` structure
- Ensure consistency across Product, Engineering, and QA layers
- Make the output production-ready for developers, testers, and stakeholders

---

## 2. Input

### Required
- `spec.md`

### Optional
- Existing `/docs` (for update mode)

---

## 3. Output Structure

You MUST generate the following structure:

/docs
  /00-overview
    changelog.md
    roadmap.md

  /01-product
    product_vision.md
    product_requirements.md
    /feature_specs

  /02-design
    ux_flows.md

  /03-engineering
    system_overview.md
    database_schema.md
    api_contract.md

  /04-quality
    test_plan.md
    /test_cases

  /05-guides
    user_guide.md

---

## 4. Core Principles

### 4.1 Single Source of Truth
- `spec.md` is the ONLY source of truth
- Do NOT invent features not present in spec
- You MAY infer missing details logically

### 4.2 Separation of Concerns
- Product = business logic, user value
- Engineering = system, DB, API
- QA = validation, test cases
- Guides = end-user instructions

### 4.3 Consistency Rules
- Naming must be consistent across all files
- Fields in DB ↔ API ↔ Test cases must match
- Feature names must be identical everywhere

---

## 5. Generation Rules

---

### 5.1 product_vision.md

Extract:
- Problem
- Solution
- Target users
- Value proposition

If missing → infer from spec context

---

### 5.2 product_requirements.md

Generate:
- Feature list
- User stories
- High-level flows

Format:
- Use "As a user..." format

---

### 5.3 feature_specs/

For EACH feature in spec:
→ create 1 file

File name:
feature_name.md

Content MUST include:
- Overview
- Actors
- Business Rules
- States (if any)
- Flow
- API (basic)
- Edge Cases
- Permissions

---

### 5.4 system_overview.md

Infer:
- Architecture (Frontend, Backend, DB)
- Data flow
- Key tech decisions (if mentioned)

---

### 5.5 database_schema.md

From spec:
- Extract entities → convert to tables
- Define:
  - columns
  - types (best guess if not specified)
  - relationships

Include:
- indexes (basic)
- RLS policy (if user-based system)

---

### 5.6 api_contract.md

For each feature:
- Define endpoints

Format:
- RESTful
- JSON request/response

Ensure:
- Matches database schema

---

### 5.7 test_plan.md

Generate:
- Scope (based on features)
- Test types
- Entry/Exit criteria

---

### 5.8 test_cases/

For EACH feature:
→ create test file

Include:
- Happy path
- Edge cases
- Invalid inputs

---

### 5.9 user_guide.md

Rewrite spec into:
- Simple, non-technical instructions

---

### 5.10 roadmap.md

Infer phases:
- MVP (core features)
- Phase 2 (enhancements)
- Phase 3 (advanced)

---

### 5.11 changelog.md

Initialize with:
- v1.0 = initial version from spec

---

## 6. Feature Detection Logic

You MUST identify features by:

- Sections in spec
- Headings
- Repeated entities (transaction, wallet, user...)

Each feature should:
- Have clear responsibility
- Be independently documented

---

## 7. Naming Conventions

- snake_case for file names
- plural for tables (transactions, users)
- REST endpoints:
  /transactions
  /wallets

---

## 8. Inference Rules

If spec is incomplete:

You MAY:
- Assume standard fields (id, created_at, updated_at)
- Assume auth system exists
- Assume user_id for ownership

You MUST NOT:
- Invent complex logic not hinted in spec

---

## 9. Output Mode

### Mode 1: Full Generation
- Generate entire `/docs`

### Mode 2: Update
- Only update affected files

---

## 10. Quality Checklist

Before finishing, ensure:

- [ ] All features have spec files
- [ ] All features have test cases
- [ ] API matches DB schema
- [ ] Naming is consistent
- [ ] No duplicated logic

---

## 11. Style Guidelines

- Use Markdown
- Prefer bullet points over long paragraphs
- Keep concise but complete
- Avoid fluff

---

## 12. Example Flow

Input:
spec.md → "User can add transaction"

Output:
- feature_specs/transaction.md
- test_cases/transaction.md
- API: POST /transactions
- DB: transactions table

---

## 13. Anti-Patterns (STRICTLY AVOID)

- ❌ Writing everything in 1 file
- ❌ Mixing product + engineering
- ❌ Inconsistent naming
- ❌ Missing test cases
- ❌ API not matching DB

---

## 14. Goal

Generate a documentation system that:
- A developer can build from directly
- A tester can test without asking
- An AI can continue extending
