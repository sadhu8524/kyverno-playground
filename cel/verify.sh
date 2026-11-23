#!/usr/bin/env bash
set -euo pipefail
k=(kubectl --context kyverno-lab -n cel-demo)
pod_label() {
  "${k[@]}" run label-probe --image=nginx:alpine --restart=Never --dry-run=server \
    -o 'jsonpath={.metadata.labels.log-type}' "$@"
}

[[ $(pod_label) == infrastructure ]]
[[ $(pod_label --labels=log-type=application) == application ]]
echo 'PASS mutation and valid override'
if denial=$(pod_label --labels=log-type=typo 2>&1); then
  echo 'Expected admission to reject log-type=typo' >&2
  exit 1
fi
[[ "$denial" == *'The lab accepts log-type infrastructure or application.'* ]] || { echo "$denial" >&2; exit 1; }
echo 'PASS validation rejected typo'

# A fresh annotation triggers an update on repeat runs.
"${k[@]}" create configmap logging-bootstrap --dry-run=client -o yaml | "${k[@]}" apply -f -
"${k[@]}" annotate configmap logging-bootstrap verification-run="$(date +%s)-$$" --overwrite
"${k[@]}" wait --for=create configmap/logging-settings --timeout=120s
[[ $("${k[@]}" get cm logging-settings -o 'jsonpath={.data.format}') == json ]]
echo 'PASS generated JSON logging settings'

"${k[@]}" create cm cleanup-sample --dry-run=client -o yaml | "${k[@]}" apply -f -
"${k[@]}" label cm cleanup-sample disposable=true --overwrite
"${k[@]}" wait --for=delete cm/cleanup-sample --timeout=180s
"${k[@]}" get cm logging-bootstrap logging-settings
echo 'PASS scheduled deletion removed the marked sample and preserved both other ConfigMaps'
