#!/usr/bin/env bash
# Every N seconds, checks each live supervised worker of a Run for a prompt only a human can answer and tells the Tech-lead once per prompt, in the mailbox of its Orca Run. It never approves anything.
# It reads Orca's observation.agentWait (worker-show --json); when Orca did not observe the worker, it falls back to worker-read --source auto, and it logs a worker it cannot observe at all.
# Usage: worker-watch.sh [<run_id> [interval_seconds]]   watch until killed (run it in tmux)
#        worker-watch.sh --once [<run_id>]                one tick printed to stdout; sends and records nothing
#        worker-watch.sh --help                           print this help and exit
# <run_id> is the Run whose workers it watches. It may be empty or omitted: it then watches the Run in RUN_ID_FILE,
# re-read on every tick.
# Config: the env file named by STACK_ENV_FILE, required (tools/README.md, "Writing the env file"); plain environment
# variables win over the env file. Variable [fallback, default]:
#   MONITOR_DIR             directory of worker-watch.seen, worker-watch.log and worker-watch.ticks [required]
#   RUN_ID_FILE             file holding the Tech-lead's Run id, read on every tick and send [TECH_LEAD_RUN_ID_FILE]
#   WATCH_INTERVAL_SECONDS  seconds between ticks when no interval argument is given [20]
#   ORCA_BIN                Orca CLI [orca, else orca-ide]
set -uo pipefail

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; }

load_env_file() {
  local f="$1" line key
  local -A preset=()
  [ -f "$f" ] || { echo "STACK_ENV_FILE not found: $f (see tools/README.md, Writing the env file)" >&2; exit 2; }
  while IFS= read -r line; do
    key="${line%%=*}"
    [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] && [ -n "${!key+x}" ] && preset[$key]="${!key}"
  done <"$f"
  # shellcheck source=/dev/null
  . "$f"
  for key in "${!preset[@]}"; do printf -v "$key" '%s' "${preset[$key]}"; done
}

ONCE=0
case "${1:-}" in
  -h|--help) usage; exit 0;;
  --once) ONCE=1; shift;;
esac
[ -n "${STACK_ENV_FILE:-}" ] || { echo "STACK_ENV_FILE is not set: set it to the stack env file (see tools/README.md, Writing the env file)" >&2; exit 2; }
load_env_file "$STACK_ENV_FILE"
[ -n "${MONITOR_DIR:-}" ] || { echo "MONITOR_DIR is not set in $STACK_ENV_FILE (see tools/README.md, Writing the env file)" >&2; exit 2; }

RUN_ID_FILE="${RUN_ID_FILE:-${TECH_LEAD_RUN_ID_FILE:-}}"
RUN_ARG="${1:-}"
INTERVAL="${2:-${WATCH_INTERVAL_SECONDS:-20}}"; [[ "$INTERVAL" =~ ^[0-9]+$ ]] || INTERVAL=20
DIR="$MONITOR_DIR"
SEEN="$DIR/worker-watch.seen"; LOG="$DIR/worker-watch.log"; TICKS="$DIR/worker-watch.ticks"
ORCA="${ORCA_BIN:-$(command -v orca || command -v orca-ide || echo orca)}"

if [ "$ONCE" = 1 ]; then
  [ -n "$RUN_ARG" ] || [ -n "$RUN_ID_FILE" ] || { echo "--once needs a <run_id> or RUN_ID_FILE" >&2; exit 2; }
else
  [ -n "$RUN_ID_FILE" ] || { echo "sending needs RUN_ID_FILE or TECH_LEAD_RUN_ID_FILE" >&2; exit 2; }
fi

run_id() { [ -n "$RUN_ID_FILE" ] && [ -s "$RUN_ID_FILE" ] && tr -d '[:space:]' <"$RUN_ID_FILE"; }
send_run() {
  local r s; r="$(run_id)"; s="${1#"[worker watch] "}"
  if [ -z "$r" ]; then echo "$(date -Is) no run id in $RUN_ID_FILE; not sent" >>"$LOG"; return; fi
  "$ORCA" orchestration send --to "run:$r" --type status --subject "[Worker watch] ${s:0:80}" --body "$1" >>"$LOG" 2>&1 \
    || echo "$(date -Is) send to run:$r failed" >>"$LOG"
}

tick_line() { if [ "$ONCE" = 1 ]; then echo "tick $1"; else echo "$(date -Is) tick $1" >>"$TICKS"; fi; }

# Writes the worker's newest transcript or terminal rows (its last two pages) to its tail file. It resumes from the
# cursor of the last page it read, because the cursor after the newest page is refused as invalid.
read_new() {
  local ctx="$1" c out nc i prev="" got=0
  local cf="$STATE/worker-watch.cursor.$ctx" tf="$STATE/worker-watch.tail.$ctx"
  c="$(cat "$cf" 2>/dev/null)"
  for i in $(seq 1 50); do
    if ! out="$("$ORCA" orchestration worker-read --dispatch "$ctx" --source auto --limit 200 ${c:+--cursor "$c"} 2>/dev/null)"; then
      [ "$got" = 1 ] && break
      if [ -n "$c" ]; then c=""; rm -f "$cf"; continue; fi
      return 1
    fi
    got=1
    printf '%s\n%s\n' "$prev" "$out" | grep -v -E '^(Source|Worker|Archived|Terminal liveness|Continuation cursor|Warning): ' >"$tf"
    prev="$out"; [ -n "$c" ] && printf '%s\n' "$c" >"$cf"
    nc="$(printf '%s\n' "$out" | sed -n 's/^Continuation cursor (opaque; pass unchanged to --cursor): //p')"
    { [ -z "$nc" ] || [ "$nc" = "$c" ]; } && break
    c="$nc"
  done
}

notify_once() {
  local key; key=$(printf '%s' "$1" | sha1sum | cut -c1-16)
  if [ "$ONCE" = 1 ]; then echo "$2"; return; fi
  grep -q "$key" "$SEEN" && return
  echo "$key" >>"$SEEN"
  echo "$(date -Is) $2" >>"$LOG"
  send_run "$2"
}

tick() {
  local run="$1"
  [ -z "$run" ] && { tick_line "no-run-id"; return; }
  "$ORCA" orchestration worker-list --run "$run" --json 2>/dev/null \
    | jq -r '(.result.workers // .result.dispatches // .result) | .[] | select(.dispatchStatus == "dispatched") | .dispatchId' \
    | while read -r ctx; do
        [ -z "$ctx" ] && continue
        obs="$("$ORCA" orchestration worker-show --dispatch "$ctx" --json 2>/dev/null | jq -c '.result.observation // {}' 2>/dev/null)"
        if [ -n "$obs" ] && jq -e 'has("agentWait")' <<<"$obs" >/dev/null; then
          wait="$(jq -c '.agentWait' <<<"$obs")"
          if [ "$wait" = null ]; then tick_line "$ctx no-wait"; continue; fi
          tick_line "$ctx wait-PENDING"
          notify_once "$ctx $wait" "[worker watch] $ctx is WAITING on a prompt only a human can answer: ${wait:0:400}"
          continue
        fi
        if ! read_new "$ctx"; then
          tick_line "$ctx unobservable"
          notify_once "unobservable $ctx" "[worker watch] $ctx cannot be observed (no agentWait, worker-read failed); read it with: orca orchestration worker-read --dispatch $ctx --source auto"
          continue
        fi
        out="$(cat "$STATE/worker-watch.tail.$ctx")"
        last_allow=$(printf '%s\n' "$out" | grep -n '^\[system\] Allow' | tail -1 | cut -d: -f1)
        if [ -z "$last_allow" ]; then tick_line "$ctx no-allow"; continue; fi
        after=$(printf '%s\n' "$out" | tail -n +"$((last_allow+1))")
        if printf '%s\n' "$after" | grep -qE '^(resolved|denied|\[assistant\]|\[tool result\])'; then tick_line "$ctx allow-resolved"; continue; fi
        tick_line "$ctx allow-PENDING"
        cmd=$(printf '%s\n' "$after" | grep -m1 '"command"' | cut -c1-400)
        notify_once "$ctx $cmd" "[worker watch] $ctx is WAITING on a permission prompt ($(printf '%s\n' "$out" | sed -n "${last_allow}p")): $cmd"
      done
}

if [ "$ONCE" = 1 ]; then
  STATE="$(mktemp -d)"; trap 'rm -rf "$STATE"' EXIT
  tick "${RUN_ARG:-$(run_id)}"; exit 0
fi
STATE="$DIR"

mkdir -p "$DIR"
touch "$SEEN"
while true; do
  tick "${RUN_ARG:-$(run_id)}"
  [ -f "$TICKS" ] && tail -n 2000 "$TICKS" > "$TICKS.tmp" && mv "$TICKS.tmp" "$TICKS"
  sleep "$INTERVAL"
done
