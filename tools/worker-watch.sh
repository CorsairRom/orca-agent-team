#!/usr/bin/env bash
# Every N seconds, checks each live supervised worker of a Run for a pending permission prompt and notifies the Tech-lead once per prompt (its Orca Run's mailbox, or its terminal). It never approves anything.
# Usage: worker-watch.sh [<run_id> [interval_seconds]]   watch until killed (run it in tmux)
#        worker-watch.sh --once [<run_id>]                one tick printed to stdout; sends and records nothing
#        worker-watch.sh --help                           print this help and exit
# <run_id> is the Run whose workers it watches. In run mode it may be empty or omitted: it then watches the Run in
# RUN_ID_FILE, re-read on every tick. In terminal mode it is required (except with --once, which falls back to RUN_ID_FILE).
# Config: the env file named by STACK_ENV_FILE (written by load-config.sh), then plain environment variables,
# which win over the env file. Variable [fallback, default]:
#   WORKER_WATCH_NOTIFY     run or terminal [NOTIFY_MODE, run]
#   WORKER_WATCH_TITLE      title of the Orca terminal it notifies in terminal mode [TECH_LEAD_TERMINAL_TITLE]
#   WORKER_WATCH_DIR        directory of worker-watch.seen, worker-watch.log and worker-watch.ticks [MONITOR_DIR, ~/.local/share/orca-agent-team/monitors]
#   RUN_ID_FILE             file holding the Tech-lead's Run id, read on every tick and send in run mode [TECH_LEAD_RUN_ID_FILE]
#   WATCH_INTERVAL_SECONDS  seconds between ticks when no interval argument is given [20]
#   ORCA_BIN                Orca CLI [orca, else orca-ide]
set -uo pipefail

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

load_env_file() {
  local f="$1" line key
  local -A preset=()
  [ -f "$f" ] || { echo "STACK_ENV_FILE not found: $f (run tools/load-config.sh)" >&2; exit 2; }
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
[ -n "${STACK_ENV_FILE:-}" ] && load_env_file "$STACK_ENV_FILE"

NOTIFY="${WORKER_WATCH_NOTIFY:-${NOTIFY_MODE:-run}}"
case "$NOTIFY" in terminal|run) ;; *) echo "WORKER_WATCH_NOTIFY must be terminal or run, not: $NOTIFY" >&2; exit 2;; esac
RUN_ID_FILE="${RUN_ID_FILE:-${TECH_LEAD_RUN_ID_FILE:-}}"
RUN_ARG="${1:-}"
INTERVAL="${2:-${WATCH_INTERVAL_SECONDS:-20}}"; [[ "$INTERVAL" =~ ^[0-9]+$ ]] || INTERVAL=20
DIR="${WORKER_WATCH_DIR:-${MONITOR_DIR:-$HOME/.local/share/orca-agent-team/monitors}}"
SEEN="$DIR/worker-watch.seen"; LOG="$DIR/worker-watch.log"; TICKS="$DIR/worker-watch.ticks"
TITLE="${WORKER_WATCH_TITLE:-${TECH_LEAD_TERMINAL_TITLE:-}}"
ORCA="${ORCA_BIN:-$(command -v orca || command -v orca-ide || echo orca)}"

if [ "$ONCE" = 1 ]; then
  [ -n "$RUN_ARG" ] || [ -n "$RUN_ID_FILE" ] || { echo "--once needs a <run_id> or RUN_ID_FILE" >&2; exit 2; }
elif [ "$NOTIFY" = terminal ]; then
  [ -n "$RUN_ARG" ] || { echo "terminal mode needs a <run_id> argument" >&2; exit 2; }
  [ -n "$TITLE" ] || { echo "terminal mode needs WORKER_WATCH_TITLE or TECH_LEAD_TERMINAL_TITLE" >&2; exit 2; }
else
  [ -n "$RUN_ID_FILE" ] || { echo "run mode needs RUN_ID_FILE or TECH_LEAD_RUN_ID_FILE" >&2; exit 2; }
fi

target() { "$ORCA" terminal list --json 2>/dev/null | jq -r --arg t "$TITLE" '[.. | objects | select((.title? // "") == $t) | (.handle // .id)] | first // empty'; }
run_id() { [ -n "$RUN_ID_FILE" ] && [ -s "$RUN_ID_FILE" ] && tr -d '[:space:]' <"$RUN_ID_FILE"; }
send_run() {
  local r s; r="$(run_id)"; s="${1#"[worker watch] "}"
  if [ -z "$r" ]; then echo "$(date -Is) no run id in $RUN_ID_FILE; not sent" >>"$LOG"; return; fi
  "$ORCA" orchestration send --to "run:$r" --type status --subject "[Worker watch] ${s:0:80}" --body "$1" >>"$LOG" 2>&1 \
    || echo "$(date -Is) send to run:$r failed" >>"$LOG"
}

tick_line() { if [ "$ONCE" = 1 ]; then echo "tick $1"; else echo "$(date -Is) tick $1" >>"$TICKS"; fi; }

tick() {
  local run="$1"
  [ -z "$run" ] && { tick_line "no-run-id"; return; }
  "$ORCA" orchestration worker-list --run "$run" --json 2>/dev/null \
    | jq -r '(.result.workers // .result.dispatches // .result) | .[] | select(.dispatchStatus == "dispatched") | "\(.dispatchId) \(.agentTerminalHandle // "")"' \
    | while read -r ctx h; do
        [ -z "$h" ] && continue
        out="$("$ORCA" terminal read --terminal "$h" 2>/dev/null)" || continue
        last_allow=$(printf '%s\n' "$out" | grep -n '^\[system\] Allow' | tail -1 | cut -d: -f1)
        if [ -z "$last_allow" ]; then tick_line "$ctx no-allow"; continue; fi
        after=$(printf '%s\n' "$out" | tail -n +"$((last_allow+1))")
        if printf '%s\n' "$after" | grep -qE '^(resolved|denied|\[assistant\]|\[tool result\])'; then tick_line "$ctx allow-resolved"; continue; fi
        tick_line "$ctx allow-PENDING"
        cmd=$(printf '%s\n' "$after" | grep -m1 '"command"' | cut -c1-400)
        msg="[worker watch] $ctx is WAITING on a permission prompt ($(printf '%s\n' "$out" | sed -n "${last_allow}p")): $cmd"
        if [ "$ONCE" = 1 ]; then echo "$msg"; continue; fi
        key=$(printf '%s %s' "$ctx" "$cmd" | sha1sum | cut -c1-16)
        grep -q "$key" "$SEEN" && continue
        echo "$key" >>"$SEEN"
        echo "$(date -Is) $msg" >>"$LOG"
        if [ "$NOTIFY" = run ]; then send_run "$msg"; continue; fi
        t="$(target)"; [ -n "$t" ] && "$ORCA" terminal send --terminal "$t" --text "$msg" --enter --wait-submit 15 >>"$LOG" 2>&1
      done
}

if [ "$ONCE" = 1 ]; then tick "${RUN_ARG:-$(run_id)}"; exit 0; fi

mkdir -p "$DIR"
touch "$SEEN"
while true; do
  tick "${RUN_ARG:-$(run_id)}"
  tail -n 2000 "$TICKS" > "$TICKS.tmp" 2>/dev/null && mv "$TICKS.tmp" "$TICKS"
  sleep "$INTERVAL"
done
