#!/usr/bin/env bash
# Feeds sample statusline JSON on stdin; checks exit code and key fields. Needs bash and jq.
set -eu
cd "$(dirname "$0")/.."
export HOME="$(mktemp -d)"  # isolate from the real ~/.claude
sample='{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":58,"context_window_size":200000},"cost":{"total_cost_usd":0.123,"total_duration_ms":724000},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"},"rate_limits":{"five_hour":{"used_percentage":37,"resets_at":1999999999},"seven_day":{"used_percentage":14,"resets_at":1999999999}}}'
strip() { sed $'s/\x1b\\[[0-9;]*m//g'; }
fail=0
for s in statusline.ascii-current.sh statusline.fancy-unicode.sh; do
  for input in "$sample" '{}'; do
    out=$(printf '%s' "$input" | bash "$s" | strip) || { echo "FAIL $s: nonzero exit"; fail=1; continue; }
    [ -n "$out" ] || { echo "FAIL $s: empty output"; fail=1; }
  done
  out=$(printf '%s' "$sample" | bash "$s" | strip)
  for want in 'Sonnet 4.6' '58%' '$0.123'; do
    case $out in *"$want"*) ;; *) echo "FAIL $s: missing '$want'"; fail=1;; esac
  done
  echo "ok $s"
done
exit $fail
