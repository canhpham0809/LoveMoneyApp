# Test Cases - Onboarding and Family Linking

## Happy Path
- TC-ONB-001: User A registers and creates family successfully.
- TC-ONB-002: User B joins with valid invite code and linking succeeds.
- TC-ONB-003: Default master data is seeded after linking.

## Edge Cases
- TC-ONB-101: Invite code expired.
- TC-ONB-102: Family already has 2 members.
- TC-ONB-103: User attempts joining while already in another family.

## Invalid Inputs
- TC-ONB-201: Empty invite code.
- TC-ONB-202: Malformed email during registration.
- TC-ONB-203: Weak password below policy.
