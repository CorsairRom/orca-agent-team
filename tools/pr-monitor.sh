#!/usr/bin/env bash
# Polls the pull requests of the stack and sends every change to the mailbox of the Tech-lead's Orca Run.
# Usage: pr-monitor.sh [interval_seconds]   poll until killed (run it in tmux)
#        pr-monitor.sh --once                 print one snapshot as JSON and exit; sends nothing
#        pr-monitor.sh --notify <message>     send one message to the Tech-lead's Run and exit
#        pr-monitor.sh --help                 print this help and exit
# Config: the env file named by STACK_ENV_FILE, required (tools/README.md, "Writing the env file"); plain environment
# variables win over the env file. Variable [fallback, default]:
#   PR_MONITOR_REPOS        space-separated owner/repo list it polls [required]
#   PR_MONITOR_AUTHOR       gh pr list --author filter [@me]
#   PR_MONITOR_MERGED_DAYS  merged PRs stay in the snapshot for this many days [2]
#   MONITOR_DIR             directory of state.json, monitor.log and pending.txt [required]
#   RUN_ID_FILE             file holding the Tech-lead's Run id, read on every send [TECH_LEAD_RUN_ID_FILE]
#   PR_INTERVAL_SECONDS     seconds between polls when no interval argument is given [300]
#   ORCA_BIN                Orca CLI [orca, else orca-ide]
set -uo pipefail

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

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

case "${1:-}" in -h|--help) usage; exit 0;; esac
[ -n "${STACK_ENV_FILE:-}" ] || { echo "STACK_ENV_FILE is not set: set it to the stack env file (see tools/README.md, Writing the env file)" >&2; exit 2; }
load_env_file "$STACK_ENV_FILE"
[ -n "${MONITOR_DIR:-}" ] || { echo "MONITOR_DIR is not set in $STACK_ENV_FILE (see tools/README.md, Writing the env file)" >&2; exit 2; }

INTERVAL="${1:-${PR_INTERVAL_SECONDS:-300}}"; [[ "$INTERVAL" =~ ^[0-9]+$ ]] || INTERVAL=300
DIR="$MONITOR_DIR"
STATE="$DIR/state.json"
LOG="$DIR/monitor.log"
read -r -a REPOS <<<"${PR_MONITOR_REPOS:-}"
AUTHOR="${PR_MONITOR_AUTHOR:-@me}"
MERGED_DAYS="${PR_MONITOR_MERGED_DAYS:-2}"
ORCA="${ORCA_BIN:-$(command -v orca || command -v orca-ide || echo orca)}"
RUN_ID_FILE="${RUN_ID_FILE:-${TECH_LEAD_RUN_ID_FILE:-}}"
[ "${#REPOS[@]}" -gt 0 ] || { echo "PR_MONITOR_REPOS is empty: set it in $STACK_ENV_FILE" >&2; exit 2; }
if [ "${1:-}" != "--once" ] && [ -z "$RUN_ID_FILE" ]; then echo "sending needs RUN_ID_FILE or TECH_LEAD_RUN_ID_FILE" >&2; exit 2; fi
mkdir -p "$DIR"

snapshot() {
  for r in "${REPOS[@]}"; do
    gh pr list -R "$r" --author "$AUTHOR" --state all --limit 40 \
      --json number,state,isDraft,mergedAt,reviewDecision,title,url,comments,reviews,baseRefName \
      --jq ".[] | select(.state==\"OPEN\" or ((.mergedAt // \"\") > \"$(date -u -d "-$MERGED_DAYS days" +%FT%TZ)\")) | {key: \"$r#\(.number)\", url, title: .title[0:60], base: .baseRefName, state, draft: .isDraft, decision: (.reviewDecision // \"\"), comments: (.comments|length), reviews: (.reviews|length), last_review: ((.reviews|last|.state) // \"\")}" \
      2>>"$LOG" || return 1
  done | jq -s 'map({(.key): .}) | add // {}'
}

run_id() { [ -s "$RUN_ID_FILE" ] && tr -d '[:space:]' <"$RUN_ID_FILE"; }

send_run() {
  "$ORCA" orchestration send --to "run:$1" --type status --subject "[PR monitor] ${2:0:80}" --body "[PR monitor] $2" >>"$LOG" 2>&1
}

notify() {
  local r; r="$(run_id)"
  if [ -z "$r" ]; then echo "$(date -Is) no run id in $RUN_ID_FILE; pending: $1" >>"$LOG"; echo "$1" >>"$DIR/pending.txt"; return; fi
  if [ -s "$DIR/pending.txt" ]; then
    send_run "$r" "(delayed) $(tr '\n' ' ' <"$DIR/pending.txt")" && : >"$DIR/pending.txt"
  fi
  send_run "$r" "$1" || echo "$1" >>"$DIR/pending.txt"
}

if [ "${1:-}" = "--once" ]; then snapshot; exit; fi
if [ "${1:-}" = "--notify" ]; then notify "${2:?message}"; exit; fi

while true; do
  if NEW="$(snapshot)"; then
    if [ -f "$STATE" ]; then
      MSG="$(jq -rn --argjson o "$(cat "$STATE")" --argjson n "$NEW" '
        [ ($n | keys[]) as $k | ($o[$k] // null) as $a | $n[$k] as $b |
          if $a == null then "NEW \($k) \($b.state)\(if $b.draft then " draft" else "" end) -> \($b.base): \($b.title) \($b.url)"
          else
            ( [ (if $a.state != $b.state then "state \($a.state)->\($b.state)" else empty end),
                (if $a.draft != $b.draft then (if $b.draft then "back to draft" else "ready for review" end) else empty end),
                (if $a.decision != $b.decision then "review decision \($a.decision)->\($b.decision)" else empty end),
                (if $b.reviews > $a.reviews then "new review (\($b.last_review))" else empty end),
                (if $b.comments > $a.comments then "\($b.comments - $a.comments) new comment(s)" else empty end) ]
              | if length > 0 then "\($k): \(join(", ")) \($b.url)" else empty end )
          end ] | join(" | ")')"
      [ -n "$MSG" ] && { echo "$(date -Is) $MSG" >>"$LOG"; notify "$MSG"; }
    fi
    echo "$NEW" >"$STATE"
  else
    echo "$(date -Is) snapshot failed" >>"$LOG"
  fi
  sleep "$INTERVAL"
done
