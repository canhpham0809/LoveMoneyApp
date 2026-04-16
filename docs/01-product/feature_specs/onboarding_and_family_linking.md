# Feature Spec - Onboarding and Family Linking

## Overview
Allow one user to create a family space and link exactly one partner.

## Actors
- User A (creator)
- User B (invitee)

## Business Rules
- One family has exactly 2 members.
- Invite code/link must be valid and not expired.
- Default master data is seeded after successful linking.

## States
- `pending_link`
- `linked`
- `invalid_invite`

## Flow
1. User A registers.
2. User A creates family and receives invite code/link.
3. User B registers and submits invite code/link.
4. System validates invite and links User B.
5. System seeds default wallet, categories, sources, funds, debt types.

## API (Basic)
- `POST /auth/register`
- `POST /families`
- `POST /families/invite`
- `POST /families/join`

## Edge Cases
- Invite code already used.
- User tries to join second family.
- Family already has 2 members.

## Permissions
- Any authenticated user can create own family.
- Join requires valid invite from target family.
