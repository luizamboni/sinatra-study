# ruby-study

Small Ruby sandbox project.

## Usage

```sh
ruby bin/run

## Signatures

RBS signatures live in `sig/app.rbs` and describe the `App` module.
```

## Docker

Build the image and run the API with Rack:

```sh
docker build -t ruby-study .
docker run --rm -p 4567:4567 ruby-study
```

Or use docker compose for a dev loop with the local code mounted:

```sh
docker compose up --build
```

## Google Cloud Spanner (local emulator)

The default `docker-compose.yml` starts the Cloud Spanner emulator and wires the app to it.
The emulator is in-memory; data is reset when the container stops.

```sh
docker compose up --build
```

Environment variables used:

```sh
APP_REPOSITORY=spanner
SPANNER_PROJECT_ID=local-project
SPANNER_INSTANCE_ID=local-instance
SPANNER_DATABASE_ID=local-db
SPANNER_EMULATOR_HOST=spanner:9010
```
