# React Frontend Test Console Spec

## 1. Goal

Define a simple React frontend that consumes the schema versioning and migration API, with enough features to execute and observe the extreme scenarios documented in:

- `0001-schema-versioning-spec.md`
- `0002-schema-migration-spec.md`

This is a test console, not a production UI.

## 2. Scope

In scope:
- API exploration and execution
- schema/version lifecycle actions
- migration lifecycle actions
- scenario-driven testing views
- visibility into links (hypermedia)

Out of scope:
- authentication/authorization
- advanced UX polish
- multi-tenant access control

## 3. Tech Stack

- React 18+
- TypeScript
- Vite
- React Router
- TanStack Query (server state, retries, caching)
- Zod (response parsing + defensive runtime validation)

## 4. App Structure

Routes:

1. `/`
- dashboard summary
- quick links to active schema keys, active migrations, failed jobs

2. `/schema-keys`
- list schema keys
- create schema key (v1)

3. `/schema-keys/:schemaKey`
- version timeline
- active version indicator
- create new version
- activate/deprecate/retire actions

4. `/schema-keys/:schemaKey/versions/:version`
- version detail (fields, required flags, breaking flag)
- links panel (`self`, `entities`, `migrations`)

5. `/entities/:schemaKey/current`
- list entities from active version
- create entity payload form (raw JSON editor + guided form)

6. `/entities/:schemaKey/versions/:version`
- same as above, pinned to specific version

7. `/schema-keys/:schemaKey/migrations`
- migration list + filters (status, from/to version, mode)
- create migration form

8. `/schema-keys/:schemaKey/migrations/:migrationId`
- status, counters, last checkpoint, failures
- actions: start/pause/resume/cancel
- live polling

9. `/scenario-lab`
- guided test flows for the extreme scenarios (Section 9)

## 5. Core UI Modules

1. `HypermediaLinkPanel`
- reads `links` from any API payload
- renders link relation + href
- “Open” and “Copy” actions

2. `SchemaVersionDiffView`
- compares two versions:
  - added fields
  - removed fields
  - type changes
  - optional/required flips

3. `MigrationProgressPanel`
- status badge
- counters (`total`, `processed`, `succeeded`, `failed`)
- progress bar
- checkpoint cursor
- failure ratio

4. `FailureSamplesTable`
- row id, error code, detail, retry action

5. `JsonRequestWorkbench`
- endpoint selector
- request body editor
- response viewer
- reproducible request history

## 6. API Contract Assumptions

The frontend expects endpoints and shapes defined in:
- `0001-schema-versioning-spec.md`
- `0002-schema-migration-spec.md`

It MUST tolerate:
- unknown extra fields
- additional link relations
- optional future status values

It MUST fail visibly if critical fields are missing (`schema_key`, `version`, `status`, `links`).

## 7. State and Data Policies

- Mutations use optimistic update only for low-risk transitions (`pause`/`resume` UI toggles optional).
- Activation and migration start must be pessimistic (server is source of truth).
- Migration detail page polls every 2s while status is `running`.
- Polling stops automatically on terminal states.

## 8. Error Handling

Display strategy:

1. `400/422`
- show inline validation errors near form/editor

2. `404`
- show “not found” page with back links

3. `409`
- show conflict panel with gate reasons + remediation links

4. network errors
- show retry affordance and last successful snapshot timestamp

All errors should render raw API `details` and `links` when available.

## 9. Scenario Lab (Extreme Cases)

Each scenario has:
- prerequisites
- setup actions
- expected results checklist
- assertions against live API responses

Scenarios:

1. Optional -> Required with massive missing data simulation
- create `vN` optional field
- create `vN+1` required field
- dry run + real migration
- verify activation blocked when policy fails

2. Crash and resume simulation
- start migration
- pause/resume sequences
- ensure counters and checkpoint monotonicity

3. Duplicate start race
- trigger rapid start requests
- verify one succeeds, one conflicts

4. Type coercion failures
- transform emits invalid types
- verify dead-letter visibility + failure counts

5. Dual-write backfill semantics
- run backfill mode
- verify dedupe indicators and consistent final state

6. Premature activation blocked
- activate during running migration
- verify `409` and gate reason rendering

7. Outage retry visibility
- test with mocked transient failures (dev mode)
- verify retry counters and final classification

8. In-place migration guardrail
- request in-place for breaking rename
- verify explicit override requirement

9. Dry run high failure ratio
- run dry-run above threshold
- ensure “start real migration” blocked unless waiver

## 10. Local Dev and Testability

Environment variables:

- `VITE_API_BASE_URL` (default `http://localhost:4567`)
- `VITE_ENABLE_SCENARIO_MOCKS` (`true|false`)

Recommended scripts:

- `npm run dev`
- `npm run test` (unit)
- `npm run test:e2e` (Playwright)

## 11. Testing Strategy

Unit tests:
- response parsing
- diff logic
- gating message rendering

Integration tests:
- mutation flows with mocked API server
- polling lifecycle

E2E tests:
- full scenario-lab happy path
- activation conflict flow
- migration start/pause/resume/cancel

## 12. Minimal Acceptance Criteria

1. User can create schema key, add version, and view diff.
2. User can run migration lifecycle from UI and see live progress.
3. User can attempt activation and see gate failures clearly.
4. User can inspect and follow hypermedia links from any response.
5. User can execute at least 5 extreme scenarios in Scenario Lab with deterministic checklists.

## 13. Non-Functional Requirements

- Initial page load under 2s in local dev.
- Migration detail polling should not exceed one request every 2s.
- All critical actions require confirmation dialog:
  - activate version
  - cancel migration
  - retire version

## 14. Future Extensions

- Timeline visualization of schema evolution.
- Migration replay tool for dead-letter items.
- Multi-schema dashboard with SLO alerts.

