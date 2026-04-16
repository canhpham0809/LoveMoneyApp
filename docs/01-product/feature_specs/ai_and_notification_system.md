# Feature Spec - AI and Notification System

## Overview
Deliver contextual reminders and AI insights without overwhelming users.

## Actors
- Family member A
- Family member B
- System scheduler

## Business Rules
- Advanced AI is gated until 30 transactions or 14 active days.
- Notifications respect user preference settings.
- Debt and budget alerts have higher priority than summaries.

## States
- AI state: `locked`, `enabled`
- Notification state: `queued`, `sent`, `dismissed`

## Flow
1. Scheduler evaluates events (budget, debt, report period).
2. System checks preferences and eligibility.
3. Notification or AI card is generated and delivered.
4. User can open related screen from notification action.

## API (Basic)
- `GET /notifications/preferences`
- `PUT /notifications/preferences`
- `GET /reports/monthly`

## Edge Cases
- User disables notification category.
- AI insight generated with insufficient data.
- Duplicate notifications for same event window.

## Permissions
- Both members manage personal notification settings.
- AI insights are readable by both family members.
