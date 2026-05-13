# Schema Migration Spec

## 1. Purpose

Define how to migrate entities between schema versions safely, especially for non-backward-compatible changes and large datasets.

This spec is focused on:
- correctness
- resumability
- observability
- controlled activation

## 2. Definitions

- `schema_key`: stable logical schema identifier (example: `teachers`)
- `from_version`: source immutable schema version
- `to_version`: target immutable schema version
- `migration job`: asynchronous process that moves or rewrites entities from `from_version` to `to_version`

## 3. Migration Modes

1. `copy` (default)
- Read source entities, write new entities at target version.
- Source remains untouched.
- Preferred for breaking changes.

2. `in_place`
- Rewrite entities under same physical records.
- Higher risk; only allowed for explicitly approved use cases.

3. `dual_write_backfill`
- Runtime already writes to both versions.
- Migration only backfills historical entities.

## 4. API Contract

## 4.1 Create job

`POST /schema-keys/:schema_key/migrations`

Request:
```json
{
  "from_version": 2,
  "to_version": 3,
  "mode": "copy",
  "transform_name": "teachers_v2_to_v3",
  "dry_run": false
}
```

Response `202`:
```json
{
  "id": "mig_123",
  "status": "planned",
  "links": {
    "self": "/schema-keys/teachers/migrations/mig_123",
    "start": "/schema-keys/teachers/migrations/mig_123/start"
  }
}
```

## 4.2 Control and status

- `POST /schema-keys/:schema_key/migrations/:id/start`
- `POST /schema-keys/:schema_key/migrations/:id/pause`
- `POST /schema-keys/:schema_key/migrations/:id/resume`
- `POST /schema-keys/:schema_key/migrations/:id/cancel`
- `GET /schema-keys/:schema_key/migrations/:id`

Status payload MUST include:
- lifecycle status
- counters
- checkpoint cursor
- failure summary
- links to retry/remediation actions

## 5. Lifecycle

States:
- `planned`
- `running`
- `paused`
- `completed`
- `failed`
- `canceled`

Valid transitions:
- `planned -> running|canceled`
- `running -> paused|completed|failed|canceled`
- `paused -> running|canceled`
- terminal: `completed|failed|canceled`

## 6. Execution Semantics

## 6.1 Ordering and checkpoint

- Process entities in deterministic order (cursor-based).
- Commit checkpoint after each successful batch.
- On resume, continue from last committed checkpoint.

## 6.2 Idempotency

Each migrated row MUST be uniquely identified by:
- `migration_id + source_entity_id`

Re-running a job MUST NOT duplicate target entities.

## 6.3 Batch policy

Suggested defaults:
- batch size: 500
- retry: exponential backoff for transient errors
- hard stop on non-recoverable transform/config errors

## 6.4 Validation

Every transformed output must pass:
1. target schema validation
2. domain validation (if configured)
3. migration-specific assertions (if configured)

Failing rows go to a dead-letter collection with:
- source id
- error code
- error detail
- raw source snapshot (or reference)

## 7. Transform Contract

Transforms are deterministic functions:

Input:
- source entity
- source schema definition
- target schema definition

Output:
- transformed attributes
- optional warnings

Hard failure conditions:
- missing required output fields
- invalid type coercion
- conflicting mapping rules

## 8. Activation Gate Rules

Version activation (`to_version` becomes active) is blocked unless:
- migration status is `completed`
- failure threshold policy is satisfied
- required validation checks pass
- approval policy passes for breaking changes

Default strict policy:
- `failed == 0`

## 9. Dry Run

If `dry_run = true`:
- run transforms and validations
- do not persist migrated entities
- still persist metrics and failure samples

Dry-run result is used for go/no-go decision before real migration.

## 10. Operational Guarantees

The tool MUST provide:
- deterministic progress metrics
- pause/resume safety
- cancellation safety (no partial silent rollback)
- auditable run history

The tool SHOULD provide:
- per-job dashboard view
- sampling of transformed output
- estimated completion time

## 11. Gherkin Scenarios (Extreme Cases)

```gherkin
Feature: Schema migration robustness
  In order to evolve schemas safely
  As a platform operator
  I want migrations to behave deterministically under extreme conditions
```

```gherkin
Scenario: Optional field becomes required with no default and huge dataset
  Given schema "students" version 4 has field "guardian_email" as optional string
  And schema "students" version 5 changes "guardian_email" to required string
  And there are 50,000,000 entities in version 4
  And 12,000,000 entities have missing "guardian_email"
  When I create a copy migration from version 4 to 5
  Then the migration must not activate version 5 automatically
  And rows missing "guardian_email" must be recorded as failed with code "REQUIRED_FIELD_MISSING"
  And successful rows must be persisted at version 5
  And migration status must be "failed" or "completed_with_failures" per policy
  And activation of version 5 must return conflict until failures are resolved or waived
```

```gherkin
Scenario: Worker crash during processing and resume from checkpoint
  Given migration "mig_200" is running for schema "teachers" from version 2 to 3
  And the last committed checkpoint is batch 140 with cursor "c140"
  When the worker process crashes during batch 141
  And I resume migration "mig_200"
  Then processing must restart from checkpoint "c140"
  And no target entity already written before the crash may be duplicated
  And final counters must match a single-pass logical result
```

```gherkin
Scenario: Duplicate migration start requests (race condition)
  Given migration "mig_300" is in state "planned"
  When two start requests are submitted concurrently
  Then exactly one request must transition the job to "running"
  And the other request must return a conflict indicating current state
  And only one worker lease may exist for "mig_300"
```

```gherkin
Scenario: Transform introduces invalid type coercion
  Given source field "hire_year" is string in version 1 data
  And target field "hire_year" in version 2 requires integer
  And transform "teachers_v1_to_v2" emits "N/A" for some rows
  When migration executes validation for target schema
  Then those rows must fail with code "TYPE_VALIDATION_ERROR"
  And failed rows must be sent to dead-letter storage
  And migration must continue processing remaining rows unless fail-fast is enabled
```

```gherkin
Scenario: Backfill under dual-write with out-of-order arrival
  Given runtime writes are dual-writing to versions 7 and 8
  And historical backfill from version 7 to 8 is running
  And late events for old entities arrive out of order
  When the backfill job processes those entities
  Then idempotency keys must prevent duplicate target rows
  And the latest logical record state must win according to deterministic conflict policy
  And migration metrics must expose deduplicated-write count
```

```gherkin
Scenario: Activation attempted before migration completion
  Given schema "classes" version 9 is draft
  And migration from version 8 to 9 is still running
  When I request activation of version 9
  Then activation must be rejected with conflict
  And response must include a link to migration status
  And response must include unmet gate reasons
```

```gherkin
Scenario: Catastrophic partial infrastructure outage
  Given 30% of write attempts to target storage fail transiently for 20 minutes
  And migration retry policy is exponential backoff with max retries
  When migration runs during the outage window
  Then transient failures must be retried until success or retry limit
  And permanent failures must be classified distinctly from transient failures
  And job must remain resumable after operator pause and resume
  And no silent data loss is allowed
```

```gherkin
Scenario: In-place migration requested for breaking rename
  Given schema "enrollments" version 3 has field "student_id"
  And schema version 4 replaces it with required field "student_external_id"
  When an in-place migration is requested from version 3 to 4
  Then the system must require explicit override approval
  And without override the request must be rejected
  And the rejection must recommend copy mode
```

```gherkin
Scenario: Dry run predicts unacceptable failure ratio
  Given dry run for migration "students 10->11" reports 18% failures
  And policy maximum allowed failure ratio is 0.5%
  When an operator requests real migration start without policy waiver
  Then the request must be rejected
  And response must include failure category summary
  And response must include remediation links
```

## 12. Non-Functional Requirements

- All migration state changes MUST be persisted transactionally.
- Metrics MUST be monotonic and auditable.
- Job status endpoint SHOULD respond in under 200ms at p95.
- Migration logs MUST include correlation ids.

## 13. Open Questions

- Should status model include explicit `completed_with_failures`?
- What is the default conflict resolution policy for late-arriving updates?
- What failure ratio thresholds should be environment-specific (dev/stage/prod)?

