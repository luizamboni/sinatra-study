# Task: Smoke-test the API

Goal: verify the API can create and list schemas, and create and list entities.

## Setup

1. Start the API: `make up`
2. Set `AGENT_BASE_URL` if needed (defaults to `http://localhost:4567`)

## Steps

1. Call `GET /schemas` and confirm it returns HTTP 200.
2. Call `POST /schemas` to create a schema (pick a unique name).
3. Call `GET /schemas` and confirm the new schema appears.
4. Call `POST /entities/:schema` to create an entity under that schema.
5. Call `GET /entities/:schema` and confirm the entity appears.

## Expected result

All calls succeed (no 5xx) and the created resources can be listed back.
