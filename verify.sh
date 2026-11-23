#!/usr/bin/env bash
set -euo pipefail

check_label() {
  local namespace=$1 name=$2 expected=$3 actual
  shift 3
  actual=$(kubectl --context kyverno-lab -n "$namespace" run "$name" \
    --image=nginx:alpine --restart=Never --dry-run=server \
    -o 'jsonpath={.metadata.labels.log-type}' "$@")
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL %s: expected <%s>, got <%s>\n' "$name" "$expected" "$actual" >&2
    return 1
  fi
  printf 'PASS %s: log-type=%s\n' "$name" "${actual:-<absent>}"
}

check_label logging-demo injected infrastructure
check_label logging-demo preserved application --labels=log-type=application
check_label ordinary-demo outside ''
