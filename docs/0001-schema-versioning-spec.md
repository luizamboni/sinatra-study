# Schema Versioning Spec

## 1. Goal

Define how schemas evolve over time, including non-backward-compatible changes, while keeping entity reads/writes deterministic and operable.

This spec applies to the current dynamic model API (`schemas` + `entities`).

## 2. Scope

In scope:
- Schema version model
- API endpoints and payloads
- Hypermedia links for discovery (Maturity Level 3)
- Migration tool contract and lifecycle
- Activation and rollout safety rules

Out of scope:
- UI design
- External event-driven CDC pipelines

## 3. Core Concepts

### 3.1 Schema Key vs Version

- `schema_key`: stable logical identifier (example: `teachers`)
- `version`: immutable schema definition number (`1`, `2`, `3`, ...)

Rule:
- Active schema versions MUST NOT be mutated in place.
- Any shape change creates a new version.

### 3.2 Version Status

Allowed statuses:
- `draft`: editable
- `active`: current write/read alias target
- `deprecated`: still readable, not default for new writes
- `retired`: no longer used for normal traffic

### 3.3 Entity Binding

Each entity stores:
- `schema_key`
- `schema_version`
- `attributes`
- timestamps and internal id

This guarantees entities are always interpreted by the schema version they were validated against.

## 4. Data Model (logical)

### 4.1 SchemaDefinition

```json
{
  "schema_key": "teachers",
  "version": 3,
  "status": "active",
  "fields": [
    { "name": "full_name", "type": "string", "required": true },
    { "name": "email", "type": "string", "required": true },
    { "name": "hire_year", "type": "integer", "required": true },
    { "name": "active", "type": "boolean", "required": true }
  ],
  "breaking": true,
  "created_at": "2026-05-13T00:00:00Z"
}
```

### 4.2 SchemaAlias

```json
{
  "schema_key": "teachers",
  "active_version": 3
}
```

### 4.3 MigrationJob

```json
{
  "id": "mig_01",
  "schema_key": "teachers",
  "from_version": 2,
  "to_version": 3,
  "mode": "copy",
  "status": "running",
  "progress": {
    "total": 1200,
    "processed": 550,
    "succeeded": 540,
    "failed": 10
  },
  "last_cursor": "opaque-cursor",
  "created_at": "2026-05-13T00:00:00Z",
  "started_at": "2026-05-13T00:10:00Z"
}
```

## 5. API Contract

## 5.1 Existing Routes (kept)

- `GET /schemas`
- `POST /schemas`
- `GET /entities/:schema`
- `POST /entities/:schema`

These can remain as compatibility aliases to `active_version`.

## 5.2 New Versioning Routes

### Create first version for a schema key

- `POST /schema-keys`

Request:
```json
{
  "schema_key": "teachers",
  "fields": [
    { "name": "full_name", "type": "string", "required": true }
  ]
}
```

Response `201`:
```json
{
  "schema_key": "teachers",
  "version": 1,
  "status": "active",
  "links": {
    "self": "/schema-keys/teachers/versions/1",
    "create_next_version": "/schema-keys/teachers/versions",
    "entities": "/entities/teachers/versions/1"
  }
}
```

### Create next version

- `POST /schema-keys/:schema_key/versions`

Request:
```json
{
  "from_version": 1,
  "breaking": true,
  "fields": [
    { "name": "full_name", "type": "string", "required": true },
    { "name": "email", "type": "string", "required": true }
  ]
}
```

Response `201` with `status: draft`.

### Get schema key overview

- `GET /schema-keys/:schema_key`

Response includes version list and current alias target.

### Get one version

- `GET /schema-keys/:schema_key/versions/:version`

### Activate a version

- `POST /schema-keys/:schema_key/versions/:version/activate`

Rules:
- Activation can be blocked by migration/validation gates (Section 8).

### Deprecate/retire version

- `POST /schema-keys/:schema_key/versions/:version/deprecate`
- `POST /schema-keys/:schema_key/versions/:version/retire`

## 5.3 Versioned Entity Routes

### Explicit version routes

- `GET /entities/:schema_key/versions/:version`
- `POST /entities/:schema_key/versions/:version`

### Alias route

- `GET /entities/:schema_key/current`
- `POST /entities/:schema_key/current`

`current` resolves to `active_version`.

## 6. Hypermedia Requirements (Level 3)

Responses MUST include navigation links.

### Example: `GET /schema-keys/teachers`

```json
{
  "schema_key": "teachers",
  "active_version": 3,
  "versions": [
    { "version": 1, "status": "retired", "links": { "self": "/schema-keys/teachers/versions/1" } },
    { "version": 2, "status": "deprecated", "links": { "self": "/schema-keys/teachers/versions/2" } },
    { "version": 3, "status": "active", "links": { "self": "/schema-keys/teachers/versions/3" } }
  ],
  "links": {
    "self": "/schema-keys/teachers",
    "create_next_version": "/schema-keys/teachers/versions",
    "entities_current": "/entities/teachers/current",
    "migrations": "/schema-keys/teachers/migrations"
  }
}
```

### Entity collection responses MUST include

- `self`
- `schema_version`
- `schema_definition`
- `schema_docs`

## 7. Migration Tool Spec

## 7.1 Migration Resource

### Create migration job

- `POST /schema-keys/:schema_key/migrations`

Request:
```json
{
  "from_version": 2,
  "to_version": 3,
  "mode": "copy",
  "transform_name": "teachers_v2_to_v3"
}
```

Response `202`:
```json
{
  "id": "mig_01",
  "status": "planned",
  "links": {
    "self": "/schema-keys/teachers/migrations/mig_01",
    "start": "/schema-keys/teachers/migrations/mig_01/start"
  }
}
```

### Control endpoints

- `POST /schema-keys/:schema_key/migrations/:id/start`
- `POST /schema-keys/:schema_key/migrations/:id/pause`
- `POST /schema-keys/:schema_key/migrations/:id/resume`
- `POST /schema-keys/:schema_key/migrations/:id/cancel`
- `GET /schema-keys/:schema_key/migrations/:id`

## 7.2 Modes

- `copy` (default): create new entities on target version
- `in_place`: rewrite version tag/data in-place (restricted)
- `dual_write_backfill`: backfill historical entities while runtime dual-writes

## 7.3 Execution Requirements

- Batched processing with cursor checkpoints
- Idempotent writes using migration-specific key
- Dead-letter capture for failed rows
- Progress counters (`total`, `processed`, `succeeded`, `failed`)

## 7.4 Transform Contract

Transforms are deterministic functions:

Input:
- source entity
- source schema version
- target schema version

Output:
- target attributes
- optional warnings

Hard failure:
- invalid output for target schema
- missing mandatory mapping

## 8. Breaking Change Policy

A version is marked `breaking` when it includes changes such as:
- optional -> required field
- field removal
- type changes
- semantic meaning changes

For `optional -> required`:
- Migration MUST provide backfill rule or failures remain blocked.
- Activation MUST fail if required-field backfill policy is not satisfied.

## 9. Activation Gates

Activation of `to_version` is allowed only if:
- target version exists and is `draft` or `deprecated`
- migration jobs from prior active version are `completed` (or explicitly waived)
- validation checks pass
- failure threshold policy passes (default strict: `failed == 0`)

If any gate fails, return `409` with details and remediation links.

## 10. Error Model

Standard status guidance:
- `400`: invalid request payload
- `404`: schema key/version/migration not found
- `409`: state conflict (activation gate failure, duplicate active version mutation)
- `422`: validation failure for entity payload

Error payload SHOULD include:
- `error`
- `details`
- `links` to next valid actions

## 11. Backward Compatibility Strategy

Compatibility for existing clients:
- Existing `/entities/:schema` maps to `/entities/:schema/current`
- Existing `/schemas` continues to work and includes version metadata/links

Deprecation communication:
- Add response header on alias routes:
  - `Deprecation: true` when policy demands
  - `Link` header to versioned endpoints

## 12. Observability

Required metrics:
- migration duration
- migration success/failure counts
- activation attempts and failures
- entity write/read counts per schema version

Required logs:
- migration state transitions
- per-batch checkpoint updates
- transform failure samples

## 13. Rollout Plan

Phase 1:
- Introduce `schema_key`, `version`, `status`, alias table
- Add versioned read/write endpoints

Phase 2:
- Add migration resources and batch executor
- Add activation gates

Phase 3:
- Enforce deprecation policy on alias routes
- Add operational dashboards

