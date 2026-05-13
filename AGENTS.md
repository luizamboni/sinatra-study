# AGENTS.md

Este repositório é um **sandbox de estudo em Ruby** com uma API HTTP simples (Sinatra/Rack), camadas bem separadas (controllers/services/domain/infrastructure) e suporte a múltiplos backends de persistência (SQLite e Google Cloud Spanner — incluindo emulador local via Docker Compose).

## Visão geral da estrutura

- `app/`
  - `api/`: entrada HTTP da aplicação (Sinatra) e rotas.
  - `controllers/`: camada de “web/controller”; parse/validação de request, serialização de response e mapeamento de erros.
  - `services/`: regras de aplicação / casos de uso (orquestra domínio + repositório).
  - `domain/`: objetos de domínio (ex.: `Schema`, `Entity`, `Field`, `Attribute`).
  - `infrastructure/`: repositórios e detalhes de persistência (`sqlite_repository.rb`, `spanner_repository.rb`).
  - `errors/`: erros de aplicação (ex.: `ValidationError`).
  - `types.rb`: tipos compartilhados (Dry Types) usados pelos controllers.
  - `app/` (subpasta): bootstrap/DI e “entrypoints” internos (ex.: `DependencyBuilder` e `App.start`).
- `bin/`: scripts de execução (run/server/dev_server/seed/console etc).
- `db/`: diretório para armazenamento local (ex.: SQLite) quando aplicável.
- `scripts/`: utilitários, incluindo inicialização do emulador do Spanner.
- `test/`: testes (Minitest) e helpers.
- `sig/` e `sorbet/`: tipagem/assinaturas (RBS e Sorbet) para estudo.
- `harness/`: harness “tool-agnostic” para agentes (docs + tasks).

## Fluxo de execução (alto nível)

1. `config.ru` carrega `app/api/app_api_routes.rb` e registra `App::Api::AppApiRoutes` no Rack.
2. `App::Api::AppApiRoutes` define endpoints (v1 e v2) e fallbacks de erro.
3. Controllers validam payloads com `dry-schema`/`dry-struct` e chamam services.
4. Services usam o repositório configurado (SQLite/Spanner) para persistir e consultar.

## Endpoints principais

- `GET /schemas`
- `POST /schemas`
- `GET /entities/:schema`
- `POST /entities/:schema`
- Swagger por schema:
  - `GET /:schema/swagger.json`
  - `GET /:schema/docs`
  - variantes v2 em `/v2/...`

## Persistência

O repositório é selecionado por `APP_REPOSITORY`:
- `spanner`: usa emulador do Cloud Spanner via `docker-compose.yml` (reset a cada restart).
- `sqlite`: usa SQLite local (depende da implementação em `app/infrastructure/sqlite_repository.rb`).

## Comandos úteis

- Rodar scripts:
  - `make run` → `bundle exec ruby bin/run`
  - `make server` → `bundle exec ruby bin/server` (Rack em `PORT` ou 4567)
  - `make dev-server` → modo dev com debug
  - `make console` → console
  - `make seed` → seed
- Testes e tipagem:
  - `make test`
  - `make rbs`
  - `make check` (test + rbs)

## Harness para agentes (humano/LLM)

O harness é pensado para qualquer agente que consiga executar comandos de shell e fazer HTTP:

- `make up` / `make down` / `make restart`: sobe/derruba o stack via Docker Compose.
- `make smoke`: smoke test determinístico via `scripts/agent_harness.sh`.
- Docs: `harness/agent_harness.md`
- Tarefas: `harness/tasks/`

Observação: os alvos `agent-*` permanecem como aliases por compatibilidade.

## Convenções e dicas ao editar

- Prefira mudanças pequenas e focadas, mantendo o padrão de camadas:
  - validação/parse no `controllers/`
  - regra de negócio/orquestração em `services/`
  - estruturas essenciais no `domain/`
  - IO/persistência em `infrastructure/`
- Evite acoplar `Sinatra` diretamente em services/domínio.
- Se alterar payloads de request/response, atualize:
  - structs/schemas em `app/controllers/**`
  - smoke test em `scripts/agent_harness.sh` (se necessário)
  - docs em `harness/` quando fizer sentido

