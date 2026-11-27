#!/usr/bin/env bash
# Every N seconds, checks each live supervised worker of a Run for a stop on a usage-limit error, and tells the Tech-lead once per error, in the mailbox of its Orca Run. It never approves anything.
# On every tick it reads each worker's newest rows (worker-read --source auto), and it reports once a worker it cannot read at all.
# Permission prompts, stops and exits without worker_done, and request errors are not its job: Orca sends the coordinator its own escalation messages for them.
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
#   WATCH_LIMIT_PATTERNS    newline-separated extended regexes of usage-limit errors, added to the built-in defaults [none]
#   ORCA_BIN                Orca CLI [orca, else orca-ide]
set -uo pipefail

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

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

# Timestamps and hashes use only POSIX date and sha1sum or shasum, so the watch runs on Linux and macOS alike.
stamp() { date +%Y-%m-%dT%H:%M:%S%z; }
sha1() { if command -v sha1sum >/dev/null; then sha1sum; else shasum -a 1; fi; }

run_id() { [ -n "$RUN_ID_FILE" ] && [ -s "$RUN_ID_FILE" ] && tr -d '[:space:]' <"$RUN_ID_FILE"; }
send_run() {
  local r s; r="$(run_id)"; s="${1#"[worker watch] "}"
  if [ -z "$r" ]; then echo "$(stamp) no run id in $RUN_ID_FILE; not sent" >>"$LOG"; return; fi
  "$ORCA" orchestration send --to "run:$r" --type status --subject "[Worker watch] ${s:0:80}" --body "$1" >>"$LOG" 2>&1 \
    || echo "$(stamp) send to run:$r failed" >>"$LOG"
}

tick_line() { if [ "$ONCE" = 1 ]; then echo "tick $1"; else echo "$(stamp) tick $1" >>"$TICKS"; fi; }

# Writes the worker's newest transcript or terminal rows (its last two pages) to its tail file. It resumes from the
# cursor of the last page it read, because the cursor after the newest page is refused as invalid.
read_new() {
  local ctx="$1" c out nc prev="" got=0
  local cf="$STATE/worker-watch.cursor.$ctx" tf="$STATE/worker-watch.tail.$ctx"
  c="$(cat "$cf" 2>/dev/null)"
  for _ in $(seq 1 50); do
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

DEFAULT_LIMIT_PATTERNS='provider\.free-limit
Free usage limit reached
usage limit reached
hit your (usage )?limit
RESOURCE_EXHAUSTED
Quota exceeded'

# Reads rows on stdin and prints the last line that matches a default or a WATCH_LIMIT_PATTERNS pattern, case-insensitively.
limit_match() {
  grep -i -E -f <(printf '%s\n%s\n' "$DEFAULT_LIMIT_PATTERNS" "${WATCH_LIMIT_PATTERNS:-}" | grep -v '^[[:space:]]*$') | tail -n 1
}

limit_check() {
  local ctx="$1" line
  line="$(limit_match <"$STATE/worker-watch.tail.$ctx")"
  [ -n "$line" ] || { tick_line "$ctx no-limit"; return 0; }
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"; line="${line:0:200}"
  tick_line "$ctx limit-HIT"
  notify_once "limit $ctx $line" "[worker watch] $ctx stopped on a usage limit: $line"
}

notify_once() {
  local key; key=$(printf '%s' "$1" | sha1 | cut -c1-16)
  if [ "$ONCE" = 1 ]; then echo "$2"; return; fi
  grep -q "$key" "$SEEN" && return
  echo "$key" >>"$SEEN"
  echo "$(stamp) $2" >>"$LOG"
  send_run "$2"
}

tick() {
  local run="$1"
  [ -z "$run" ] && { tick_line "no-run-id"; return; }
  # --full: since Orca 1.4.246 --json alone prints a concise view without dispatchStatus.
  "$ORCA" orchestration worker-list --run "$run" --json --full 2>/dev/null \
    | jq -r '(.result.workers // .result.dispatches // .result) | .[] | select(.dispatchStatus == "dispatched") | .dispatchId' \
    | while read -r ctx; do
        [ -z "$ctx" ] && continue
        if ! read_new "$ctx"; then
          tick_line "$ctx unobservable"
          notify_once "unobservable $ctx" "[worker watch] $ctx cannot be observed (worker-read failed); read it with: orca orchestration worker-read --dispatch $ctx --source auto"
          continue
        fi
        limit_check "$ctx"
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
