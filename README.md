# Projeto Ethan

Projeto Ethan is a B2B procurement workflow platform that connects buyers and suppliers
from quotation to fiscal validation in one auditable flow.

Core capabilities:

- verified authentication and role-based onboarding;
- RFQ (quotation) creation by buyers;
- proposal submission by suppliers;
- proposal selection and closure workflow;
- invoice XML upload and review in-product;
- support tickets and operational AI assistant.

## Why this product exists

In many B2B operations, procurement is fragmented across WhatsApp, email,
spreadsheets, and disconnected systems. The result is predictable:

- weak decision traceability;
- identity and onboarding inconsistencies;
- manual rework at purchase close;
- fiscal validation risk and delayed approvals.

Projeto Ethan addresses this by centralizing commercial negotiation and fiscal
compliance in a single operational product.

## Product intent

1. Reduce procurement execution risk.
2. Increase trust between buyers and suppliers.
3. Eliminate off-platform handoffs at critical steps.
4. Provide audit-ready identity, pricing, and XML decision trails.

## Workflow

1. User creates an account and chooses role (`buyer` or `supplier`).
2. Account verifies email.
3. User completes company and responsible-person profile.
4. Buyer publishes a quotation with items/specs.
5. Suppliers submit price and lead-time proposals.
6. Buyer selects the winning proposal.
7. Supplier uploads invoice XML.
8. Buyer reviews XML consistency and closes purchase.

## Technical approach

### Identity and session integrity

- Firebase Auth for secure authentication and session persistence.
- Access gates are explicit and ordered:
  - authenticated user;
  - `emailVerified == true`;
  - profile completion (`profileCompleted == true`).

### Profile consistency model

- User profile is always anchored at `users/{uid}` (never `add()` for user identity).
- Idempotent profile bootstrap on first sign-in.
- Canonical profile writes to prevent `profileCompleted` regression.
- Legacy incomplete profiles can be reprocessed safely.

### Domain model

Main collections:

- `users`
- `quotations`
- `proposals`
- `support_tickets`
- `quotations/{quotationId}/invoiceXmls/{proposalId}`

Authorization is enforced by Firestore Rules with role and state-aware policies
across buyer, supplier, proposal, and fiscal review transitions.

### Support and AI layer

- Native support ticket creation with category/status.
- Floating assistant in core operational screens.
- Ollama integration via configurable endpoint (`OLLAMA_BASE_URL`) with safe fallback
  when unavailable.

## Problem-solution fit

Expected operational outcomes:

- fewer incomplete/unsafe company registrations;
- lower procurement rework at close;
- stronger traceability of pricing and award decisions;
- fiscal validation embedded into the business flow.

## Stack

- Flutter
- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Ollama (through an intermediary support service)

## Local run

```bash
flutter clean
flutter pub get
flutter analyze lib
flutter run -d chrome
```

## Repository

Official source: [7Genesis/Ethan](https://github.com/7Genesis/Ethan)
