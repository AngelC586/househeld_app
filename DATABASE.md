# Househeld Database — Class Demo

Firebase project: test-c61a1
Database: Cloud Firestore
Demo household ID: demo-household

This demo uses online Firebase, not the Firebase Local Emulator Suite.

## User profiles

Path: users/{uid}

The document ID is the Firebase Authentication UID.

Fields:
- username: string
- email: string
- displayName: string

The authentication code should save this profile after account creation.
Passwords are managed by Firebase Authentication, never stored here.

## Household

Path: households/demo-household

Fields:
- householdName: string — "Demo Household"

This household already exists.

## Joining the household

Path: households/demo-household/members/{uid}

The membership document ID must match the signed-in user's UID.

Fields:
- userID: string — the signed-in user's UID
- householdID: string — "demo-household"
- memberRole: string — "member"

The Join button should create this document if it does not already exist.
Wait for the write to succeed before loading or adding tasks.

For this demo, any signed-in user may join this household.

## Tasks

Collection: households/demo-household/tasks

Create each task with an automatically generated document ID.

Required fields:
- taskName: string — 1–200 characters
- taskDescription: string — may be empty
- taskStatus: string — "pending"
- createdByMemberID: string — the signed-in user's UID

The current rules accept only these four fields when creating a task.

To mark a pending task complete, update:
- taskStatus: "completed"
- completedByMemberID: the signed-in user's UID
- taskCompletionTime: FieldValue.serverTimestamp()

Only household members may read, add, or complete tasks.
Other task edits, reopening, and deletion are not supported yet.

## Current status

- Online database and demo household created.
- Temporary member demo-user-1 and a sample task added.
- Firestore access rules published.
- demo-user-1 is sample data, not an Authentication account.
- Task creation was denied in a manual rules test; cause is unresolved.
- The real sign-in → join → add task flow still needs testing.