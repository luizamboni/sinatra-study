#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${AGENT_BASE_URL:-http://localhost:4567}"
TIMEOUT_SECONDS="${AGENT_TIMEOUT_SECONDS:-30}"

say() { printf "%s\n" "$*"; }
die() { say "ERROR: $*"; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

http_code() {
  # Usage: http_code METHOD URL [DATA_JSON]
  local method="$1"
  local url="$2"
  local data="${3:-}"

  if [[ -n "$data" ]]; then
    curl -sS -o /dev/null -w "%{http_code}" \
      -X "$method" "$url" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -sS -o /dev/null -w "%{http_code}" \
      -X "$method" "$url"
  fi
}

wait_for_api() {
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if [[ "$(http_code GET "$BASE_URL/schemas")" == "200" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

smoke() {
  need curl

  say "Base URL: $BASE_URL"
  say "Waiting up to ${TIMEOUT_SECONDS}s for API..."
  if ! wait_for_api; then
    die "API not reachable at $BASE_URL (GET /schemas did not return 200)"
  fi

  local run_id="agent_${RANDOM}"
  local teachers_schema="teachers_${run_id}"
  local students_schema="students_${run_id}"
  local classes_schema="classes_${run_id}"
  local enrollments_schema="enrollments_${run_id}"
  local assignments_schema="class_assignments_${run_id}"

  say "1) GET /schemas"
  [[ "$(http_code GET "$BASE_URL/schemas")" == "200" ]] || die "GET /schemas failed"

  say "2) POST /schemas (create school domain schemas)"
  local code

  # Payload shape matches App::Controllers::Schemas::CreateSchemaRequest
  code="$(http_code POST "$BASE_URL/schemas" "$(printf '%s' "{\"name\":\"$teachers_schema\",\"fields\":[{\"name\":\"full_name\",\"type\":\"string\"},{\"name\":\"email\",\"type\":\"string\"},{\"name\":\"hire_year\",\"type\":\"integer\"},{\"name\":\"active\",\"type\":\"boolean\"}]}")")"
  [[ "$code" == "201" || "$code" == "200" ]] || die "POST /schemas (teachers) unexpected HTTP $code"

  code="$(http_code POST "$BASE_URL/schemas" "$(printf '%s' "{\"name\":\"$students_schema\",\"fields\":[{\"name\":\"full_name\",\"type\":\"string\"},{\"name\":\"grade_level\",\"type\":\"integer\"},{\"name\":\"enrollment_year\",\"type\":\"integer\"},{\"name\":\"active\",\"type\":\"boolean\"}]}")")"
  [[ "$code" == "201" || "$code" == "200" ]] || die "POST /schemas (students) unexpected HTTP $code"

  code="$(http_code POST "$BASE_URL/schemas" "$(printf '%s' "{\"name\":\"$classes_schema\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"room\",\"type\":\"string\"},{\"name\":\"capacity\",\"type\":\"integer\"},{\"name\":\"active\",\"type\":\"boolean\"}]}")")"
  [[ "$code" == "201" || "$code" == "200" ]] || die "POST /schemas (classes) unexpected HTTP $code"

  code="$(http_code POST "$BASE_URL/schemas" "$(printf '%s' "{\"name\":\"$enrollments_schema\",\"fields\":[{\"name\":\"student_id\",\"type\":\"string\"},{\"name\":\"class_id\",\"type\":\"string\"},{\"name\":\"enrolled_year\",\"type\":\"integer\"},{\"name\":\"active\",\"type\":\"boolean\"}]}")")"
  [[ "$code" == "201" || "$code" == "200" ]] || die "POST /schemas (enrollments) unexpected HTTP $code"

  code="$(http_code POST "$BASE_URL/schemas" "$(printf '%s' "{\"name\":\"$assignments_schema\",\"fields\":[{\"name\":\"teacher_id\",\"type\":\"string\"},{\"name\":\"class_id\",\"type\":\"string\"},{\"name\":\"year\",\"type\":\"integer\"},{\"name\":\"active\",\"type\":\"boolean\"}]}")")"
  [[ "$code" == "201" || "$code" == "200" ]] || die "POST /schemas (class_assignments) unexpected HTTP $code"

  say "3) Seed a few entities for each schema"
  # teachers
  code="$(http_code POST "$BASE_URL/entities/$teachers_schema" '{"attributes":[{"name":"full_name","value":"Ada Lovelace"},{"name":"email","value":"ada@school.test"},{"name":"hire_year","value":2020},{"name":"active","value":true}]}')"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (teachers) unexpected HTTP $code"
  code="$(http_code POST "$BASE_URL/entities/$teachers_schema" '{"attributes":[{"name":"full_name","value":"Alan Turing"},{"name":"email","value":"alan@school.test"},{"name":"hire_year","value":2018},{"name":"active","value":true}]}')"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (teachers #2) unexpected HTTP $code"

  # students
  code="$(http_code POST "$BASE_URL/entities/$students_schema" '{"attributes":[{"name":"full_name","value":"Grace Hopper"},{"name":"grade_level","value":11},{"name":"enrollment_year","value":2023},{"name":"active","value":true}]}')"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (students) unexpected HTTP $code"
  code="$(http_code POST "$BASE_URL/entities/$students_schema" '{"attributes":[{"name":"full_name","value":"Katherine Johnson"},{"name":"grade_level","value":12},{"name":"enrollment_year","value":2022},{"name":"active","value":true}]}')"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (students #2) unexpected HTTP $code"

  # classes
  code="$(http_code POST "$BASE_URL/entities/$classes_schema" '{"attributes":[{"name":"name","value":"Math 101"},{"name":"room","value":"B-12"},{"name":"capacity","value":30},{"name":"active","value":true}]}')"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (classes) unexpected HTTP $code"
  code="$(http_code POST "$BASE_URL/entities/$classes_schema" '{"attributes":[{"name":"name","value":"CS 201"},{"name":"room","value":"C-07"},{"name":"capacity","value":25},{"name":"active","value":true}]}')"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (classes #2) unexpected HTTP $code"

  # enrollments (using simple string IDs as placeholders)
  code="$(http_code POST "$BASE_URL/entities/$enrollments_schema" "$(printf '%s' "{\"attributes\":[{\"name\":\"student_id\",\"value\":\"student-1\"},{\"name\":\"class_id\",\"value\":\"class-1\"},{\"name\":\"enrolled_year\",\"value\":2024},{\"name\":\"active\",\"value\":true}]}")")"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (enrollments) unexpected HTTP $code"

  # class assignments
  code="$(http_code POST "$BASE_URL/entities/$assignments_schema" "$(printf '%s' "{\"attributes\":[{\"name\":\"teacher_id\",\"value\":\"teacher-1\"},{\"name\":\"class_id\",\"value\":\"class-1\"},{\"name\":\"year\",\"value\":2024},{\"name\":\"active\",\"value\":true}]}")")"
  [[ "$code" == "200" || "$code" == "201" ]] || die "POST /entities (class_assignments) unexpected HTTP $code"

  say "4) Verify entities can be listed back"
  [[ "$(http_code GET "$BASE_URL/entities/$teachers_schema")" == "200" ]] || die "GET /entities/$teachers_schema failed"
  [[ "$(http_code GET "$BASE_URL/entities/$students_schema")" == "200" ]] || die "GET /entities/$students_schema failed"
  [[ "$(http_code GET "$BASE_URL/entities/$classes_schema")" == "200" ]] || die "GET /entities/$classes_schema failed"
  [[ "$(http_code GET "$BASE_URL/entities/$enrollments_schema")" == "200" ]] || die "GET /entities/$enrollments_schema failed"
  [[ "$(http_code GET "$BASE_URL/entities/$assignments_schema")" == "200" ]] || die "GET /entities/$assignments_schema failed"

  say "OK: smoke tests passed"
}

case "${1:-smoke}" in
  smoke) smoke ;;
  *)
    say "Usage: $0 smoke"
    exit 2
    ;;
esac
