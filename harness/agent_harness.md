# AI Agent Harness (tool-agnostic)

This repo includes a small, **general-purpose harness** to let any AI agent (or a human) interact with the running API in a repeatable way.

The harness is intentionally **agent-runtime agnostic**:
- no OpenAI/Claude/LangChain dependency
- the "agent" can be a human with `curl`, or any LLM that can run shell commands

## What the harness provides

- A repeatable way to start/stop the API with Docker Compose
- A stable API base URL convention
- A smoke-test script that validates the API is reachable and can create/list schemas and entities
- A small set of tasks/prompts an agent can follow

## Quick start

From repo root:

```sh
make up
make smoke
make down
```

## Environment variables

- `AGENT_BASE_URL` (default `http://localhost:4567`)
- `AGENT_TIMEOUT_SECONDS` (default `30`)

## Suggested agent workflow

1. Start the system: `make up`
2. Run smoke tests to confirm connectivity: `make smoke`
3. Run tasks from `harness/tasks/` (copy/paste as agent instructions)
4. Stop the system: `make down`
   
Notes:
- Use os alvos `make up/down/smoke` para o fluxo do harness.
