# React School App Spec

## 1. Goal

Define a simple React school app that consumes the schema/versioning API to manage school data (teachers, students, classes, enrollments), and also allows users to customize schemas and evolve them safely over time.

- `0001-schema-versioning-spec.md`
- `0002-schema-migration-spec.md`

This is a domain app first, with testing capabilities as a secondary mode.

## 2. Scope

In scope:
- school-domain workflows (teachers, students, classes, enrollments, assignments)
- navigation powered by API links/hypermedia
- end-user schema customization (field add/remove/type/required changes)
- end-user schema evolution lifecycle (new version, migration, activation)
- scenario-driven checks for breaking changes affecting school features

Out of scope:
- authentication/authorization
- multi-tenant access control

## 3. Tech Stack

- React 18+
- TypeScript
- Vite
- React Router
- TanStack Query (server state, retries, caching)
- Zod (response parsing + defensive runtime validation)

## 4. App Structure (School Domain)

Routes:

1. `/`
- dashboard summary
- KPIs (students count, classes count, active teachers)
- quick actions (new student, new class, assign teacher)
- alerts (migration in progress, schema activation impact)

2. `/teachers`
- list teachers
- create/edit teacher records
- view teacher assignments

3. `/students`
- list students
- create/edit student records
- view enrollments

4. `/classes`
- list classes
- create/edit class records
- view roster and assigned teacher

5. `/enrollments`
- enroll/unenroll students in classes
- show enrollment status and effective dates (if present)

6. `/assignments`
- assign teachers to classes
- list active assignments

7. `/ops/schema-health` (secondary, ops-aware)
- read-only schema/version summary per school entity
- active version and pending migrations
- links to migration details when present

8. `/ops/migrations/:schemaKey/:migrationId` (secondary)
- migration progress and failures affecting school entity workflows
- no raw schema editing in this screen

9. `/qa/scenario-lab`
- guided school-centric test flows for extreme migration/versioning scenarios

10. `/schema-designer`
- list customizable schema keys
- create new schema key templates for school entities
- open a schema in visual designer

11. `/schema-designer/:schemaKey`
- edit draft/new version fields
- set type and required/optional flags
- preview impact warnings (breaking vs non-breaking)
- save as new version

12. `/schema-designer/:schemaKey/versions/:version/release`
- run migration wizard
- dry run, inspect failures, start migration
- activate/deprecate versions

## 5. Core UI Modules

1. `DomainListPage`
- reusable list + filters + pagination for teachers/students/classes

2. `DomainFormPage`
- create/update forms for school entities with API-backed validation

3. `RelationshipEditor`
- student-class enrollment and teacher-class assignment editor

4. `HypermediaLinkPanel`
- reads `links` from any API payload
- resolves domain actions from links where possible
- exposes raw links in an expandable diagnostics panel

5. `SchemaVersionDiffView` (ops/qa)
- compares two versions:
  - added fields
  - removed fields
  - type changes
  - optional/required flips

6. `MigrationProgressPanel` (ops/qa)
- status badge
- counters (`total`, `processed`, `succeeded`, `failed`)
- progress bar
- checkpoint cursor
- failure ratio

7. `FailureSamplesTable` (ops/qa)
- row id, error code, detail, retry action

8. `ImpactBanner`
- warns when active migration/version may affect a school workflow
- shows “what changed” in business terms (example: `students.guardian_email is now required`)

9. `SchemaDesigner`
- visual field editor for a schema version draft
- supports add, remove, rename, type change, required toggle
- emits structured change set and breaking-change classification

10. `SchemaEvolutionWizard`
- step-by-step: draft version -> diff review -> migration plan -> dry run -> execute -> activate
- blocks unsafe progression when activation gates are unmet

## 6. API Contract Assumptions

The frontend expects endpoints and shapes defined in:
- `0001-schema-versioning-spec.md`
- `0002-schema-migration-spec.md`

It MUST tolerate:
- unknown extra fields
- additional link relations
- optional future status values

It MUST fail visibly if critical fields are missing for used workflows (entity payload fields + `links`; and in ops screens: `schema_key`, `version`, `status`).

## 7. State and Data Policies

- Domain CRUD is pessimistic by default (truth from server).
- Limited optimistic updates allowed for local UI responsiveness (table row pending states).
- Ops migration polling every 2s while `running`, stop on terminal states.
- Schema evolution actions (create version, migrate, activate) are always pessimistic.

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

All errors should render domain-friendly messages first, with raw API `details`/`links` in expandable diagnostics.

Schema designer specific errors:
- invalid field definitions show inline by row
- breaking change warnings require explicit user confirmation
- activation conflicts show unmet gate checklist and links to migration status

## 9. Scenario Lab (School-Centric Extreme Cases)

Each scenario has:
- prerequisites
- setup actions
- expected results checklist
- assertions against live API responses

Scenarios:

1. Student field becomes required with legacy gaps
- example: `guardian_email` optional -> required
- dry run + real migration
- verify activation blocked when policy fails

2. Crash and resume simulation
- start migration for `students` or `teachers`
- pause/resume sequences
- ensure counters and checkpoint monotonicity

3. Duplicate migration start race
- trigger rapid start requests
- verify one succeeds, one conflicts

4. Type coercion failures in school fields
- example: `hire_year` receives `N/A`
- verify dead-letter visibility + failure counts

5. Dual-write backfill semantics for enrollments
- run backfill mode
- verify dedupe indicators and consistent final state

6. Premature activation blocked for classes
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

10. User customizes schema and safely releases it
- add field in schema designer
- mark required and trigger migration plan
- dry run and resolve failures
- activate only after gates pass

## 10. Local Dev and Testability

Environment variables:

- `VITE_API_BASE_URL` (default `http://localhost:4567`)
- `VITE_ENABLE_SCENARIO_MOCKS` (`true|false`)
- `VITE_ENABLE_OPS_PAGES` (`true|false`, default `true` in dev, `false` in demo)

Recommended scripts:

- `npm run dev`
- `npm run test` (unit)
- `npm run test:e2e` (Playwright)

## 11. Testing Strategy

Unit tests:
- response parsing
- domain mappers (attributes <-> form models)
- impact banner rendering

Integration tests:
- mutation flows with mocked API server
- enrollment/assignment flows
- polling lifecycle (ops pages)

E2E tests:
- teacher/student/class CRUD happy paths
- enrollment and assignment flows
- schema designer create-version flow
- schema evolution wizard dry-run and activation flow
- scenario-lab activation conflict flow
- migration start/pause/resume/cancel in ops context

## 12. Minimal Acceptance Criteria

1. User can manage teachers, students, classes, enrollments, and assignments from the UI.
2. Domain pages consume API links instead of hardcoding all navigation paths.
3. User can customize schema definitions from the app and create new versions.
4. User can run migration + activation flow from the app with explicit safety gates.
5. User can see if a schema/migration issue may affect current domain actions.
6. User can execute at least 5 school-centric extreme scenarios in Scenario Lab.

## 13. Non-Functional Requirements

- Initial page load under 2s in local dev.
- Migration detail polling should not exceed one request every 2s.
- All critical actions require confirmation dialog:
  - activate version (ops)
  - cancel migration
  - retire/deprecate version (ops)

## 14. Future Extensions

- Attendance and grading modules.
- Parent contact and guardianship model.
- Migration replay tool for dead-letter items.
