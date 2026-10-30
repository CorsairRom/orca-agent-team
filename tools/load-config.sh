#!/usr/bin/env bash
# Reads the stack configuration, validates it and writes a shell-sourceable env file for the monitors.
# Usage: load-config.sh [--config <file>] [--out <file>] [--stdout] [--check]
#   --config <file>  configuration to read [$STACK_CONFIG, else config/stack.yaml next to this tools/ directory]
#   --out <file>     env file to write [$STACK_ENV_FILE, else ~/.local/share/<stack.id>/stack.env]
#   --stdout         print the env file instead of writing it
#   --check          validate only; write and print nothing
#   -h, --help       print this help and exit
# Requires yq v4 (mikefarah/yq) and jq. YQ_BIN and JQ_BIN select other binaries.
set -euo pipefail

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${STACK_CONFIG:-$SCRIPT_DIR/../config/stack.yaml}"
OUT="${STACK_ENV_FILE:-}"
MODE="write"
YQ="${YQ_BIN:-yq}"
JQ="${JQ_BIN:-jq}"

while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2:?--config needs a file}"; shift 2;;
    --out) OUT="${2:?--out needs a file}"; shift 2;;
    --stdout) MODE=stdout; shift;;
    --check) MODE=check; shift;;
    -h|--help) usage; exit 0;;
    *) echo "load-config: unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

command -v "$JQ" >/dev/null || { echo "load-config: jq not found (JQ_BIN=$JQ)" >&2; exit 2; }
command -v "$YQ" >/dev/null || { echo "load-config: yq not found (YQ_BIN=$YQ); install yq v4 from mikefarah/yq" >&2; exit 2; }
YQ_VERSION="$("$YQ" --version 2>&1 || true)"
if [[ "$YQ_VERSION" != *mikefarah* || ! "$YQ_VERSION" =~ version\ v?4\. ]]; then
  echo "load-config: yq v4 from mikefarah/yq is required, found: $YQ_VERSION" >&2; exit 2
fi
[ -f "$CONFIG" ] || { echo "load-config: configuration not found: $CONFIG (copy config/stack.example.yaml to config/stack.yaml, or set STACK_CONFIG)" >&2; exit 2; }

JSON="$("$YQ" -o=json '.' "$CONFIG")" || { echo "load-config: $CONFIG is not valid YAML" >&2; exit 2; }

# shellcheck disable=SC2016
ERRORS="$("$JQ" -r '
  def str: type == "string" and length > 0;
  def int_min($m): type == "number" and . == floor and . >= $m;
  def need($path; $v; cond; $what): if ($v | cond) then empty else "\($path): \($what)" end;
  def kinds: ["hub", "frontend", "backend", "docs", "infra", "other"];
  def efforts: ["low", "medium", "high", "xhigh", "max"];
  if type != "object" then "the file must be a YAML mapping" else
  [
    need("stack.id"; .stack.id; type == "string" and test("^[a-z0-9-]+$"); "required, lowercase letters, digits and hyphens only ([a-z0-9-]+)"),
    need("stack.name"; .stack.name; str; "required, a non-empty string"),
    need("repos"; .repos; type == "array" and length > 0; "required, a non-empty list"),
    ( if (.repos | type) == "array" then
        ( .repos | to_entries[] | .key as $i | .value as $r |
          ( if ($r | type) != "object" then "repos[\($i)]: must be a mapping" else
              need("repos[\($i)].name"; $r.name; str; "required, a non-empty string"),
              need("repos[\($i)].path"; $r.path; str; "required, a non-empty string"),
              need("repos[\($i)].remote"; $r.remote; type == "string" and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"); "required, GitHub owner/repo"),
              need("repos[\($i)].main_branch"; $r.main_branch; str; "required, a non-empty string"),
              need("repos[\($i)].kind"; $r.kind; . as $k | kinds | index([$k]) != null; "required, one of \(kinds | join(" | "))")
            end ) ),
        ( [.repos[] | objects | select(.kind == "hub")] | length | if . == 1 then empty else "repos: exactly one repository must have kind hub, found \(.)" end ),
        ( [.repos[] | objects | .name | strings] | group_by(.) | map(select(length > 1) | .[0]) | .[] | "repos: duplicate name \(.)" )
      else empty end ),
    need("memory.engram_project"; .memory.engram_project; str; "required, a non-empty string"),
    need("memory.topic_prefix"; .memory.topic_prefix; str; "required, a non-empty string"),
    need("language.owner_conversation"; .language.owner_conversation; str; "required, a non-empty string"),
    need("language.artifacts"; .language.artifacts; str; "required, a non-empty string"),
    need("language.app_copy"; .language.app_copy; str; "required, a non-empty string"),
    need("language.app_copy_rules"; .language.app_copy_rules; . == null or (type == "array" and all(.[]; type == "string")); "optional, a list of strings"),
    ( ["ideas", "tech_lead", "senior", "mid", "junior"][] as $role |
      need("models.\($role).model"; .models[$role].model?; str; "required, a Claude Code model id"),
      need("models.\($role).effort"; .models[$role].effort?; . as $e | efforts | index([$e]) != null; "required, one of \(efforts | join(" | "))") ),
    need("orca.chat_ui"; .orca.chat_ui; . == null or type == "boolean"; "optional, true or false"),
    need("orca.agent_sleep"; .orca.agent_sleep; . == null or type == "boolean"; "optional, true or false"),
    need("orca.agent_dashboard"; .orca.agent_dashboard; . == null or type == "boolean"; "optional, true or false"),
    need("orca.notify_mode"; .orca.notify_mode; . == null or . == "run" or . == "terminal"; "optional, run or terminal"),
    need("orca.tech_lead_terminal_title"; .orca.tech_lead_terminal_title; . == null or type == "string"; "optional, a string"),
    ( if .orca.notify_mode == "terminal" then
        need("orca.tech_lead_terminal_title"; .orca.tech_lead_terminal_title; str; "required when orca.notify_mode is terminal")
      else empty end ),
    need("monitors.pr_interval_seconds"; .monitors.pr_interval_seconds; . == null or int_min(1); "optional, an integer >= 1"),
    need("monitors.watch_interval_seconds"; .monitors.watch_interval_seconds; . == null or int_min(1); "optional, an integer >= 1"),
    need("monitors.pr_author"; .monitors.pr_author; . == null or str; "optional, a non-empty string"),
    need("monitors.merged_window_days"; .monitors.merged_window_days; . == null or int_min(0); "optional, an integer >= 0")
  ] | .[] end
' <<<"$JSON")"

if [ -n "$ERRORS" ]; then
  echo "load-config: $CONFIG is invalid:" >&2
  while IFS= read -r e; do echo "  - $e"; done <<<"$ERRORS" >&2
  exit 1
fi

STACK_ID="$("$JQ" -r '.stack.id' <<<"$JSON")"
STACK_DIR="$HOME/.local/share/$STACK_ID"
[ -n "$OUT" ] || OUT="$STACK_DIR/stack.env"

# shellcheck disable=SC2016
ENV_TEXT="$("$JQ" -r --arg home "$HOME" --arg config "$CONFIG" '
  def expand: if . == "~" then $home elif startswith("~/") then $home + .[1:] else . end;
  def kv($k; $v): "\($k)=\($v | tostring | @sh)";
  def bool($v; $d): if $v == null then $d else $v end;
  .stack.id as $id |
  ($home + "/.local/share/" + $id) as $stack_dir |
  ($home + "/.local/share/" + $id + "-ideas") as $ideas_dir |
  ($home + "/.local/share/" + $id + "-tech-lead") as $tl_dir |
  (.repos | map(select(.kind == "hub")) | first) as $hub |
  "# Generated by tools/load-config.sh from \($config). Do not edit; edit the configuration and run the loader again.",
  kv("STACK_ID"; $id),
  kv("STACK_NAME"; .stack.name),
  kv("STACK_DIR"; $stack_dir),
  kv("HUB_NAME"; $hub.name),
  kv("HUB_PATH"; $hub.path | expand),
  kv("HUB_REMOTE"; $hub.remote),
  kv("HUB_MAIN_BRANCH"; $hub.main_branch),
  kv("REPO_COUNT"; .repos | length),
  ( .repos | to_entries[] |
      kv("REPO_\(.key)_NAME"; .value.name),
      kv("REPO_\(.key)_PATH"; .value.path | expand),
      kv("REPO_\(.key)_REMOTE"; .value.remote),
      kv("REPO_\(.key)_MAIN_BRANCH"; .value.main_branch),
      kv("REPO_\(.key)_KIND"; .value.kind) ),
  kv("PR_MONITOR_REPOS"; reduce .repos[].remote as $r ([]; if index([$r]) then . else . + [$r] end) | join(" ")),
  kv("ENGRAM_PROJECT"; .memory.engram_project),
  kv("TOPIC_PREFIX"; .memory.topic_prefix),
  kv("LANG_OWNER_CONVERSATION"; .language.owner_conversation),
  kv("LANG_ARTIFACTS"; .language.artifacts),
  kv("LANG_APP_COPY"; .language.app_copy),
  kv("APP_COPY_RULES"; (.language.app_copy_rules // []) | join("\n")),
  ( .models | to_entries[] |
      kv("MODEL_\(.key | ascii_upcase)"; .value.model),
      kv("EFFORT_\(.key | ascii_upcase)"; .value.effort) ),
  kv("ORCA_CHAT_UI"; bool(.orca.chat_ui; true)),
  kv("ORCA_AGENT_SLEEP"; bool(.orca.agent_sleep; false)),
  kv("ORCA_AGENT_DASHBOARD"; bool(.orca.agent_dashboard; true)),
  kv("IDEAS_DIR"; $ideas_dir),
  kv("TECH_LEAD_DIR"; $tl_dir),
  kv("IDEAS_RUN_ID_FILE"; $ideas_dir + "/run-id.txt"),
  kv("TECH_LEAD_RUN_ID_FILE"; $tl_dir + "/run-id.txt"),
  kv("RUN_ID_FILE"; $tl_dir + "/run-id.txt"),
  kv("NOTIFY_MODE"; .orca.notify_mode // "run"),
  kv("TECH_LEAD_TERMINAL_TITLE"; .orca.tech_lead_terminal_title // ""),
  kv("MONITOR_DIR"; $stack_dir + "/monitors"),
  kv("PR_INTERVAL_SECONDS"; .monitors.pr_interval_seconds // 300),
  kv("WATCH_INTERVAL_SECONDS"; .monitors.watch_interval_seconds // 20),
  kv("PR_MONITOR_AUTHOR"; .monitors.pr_author // "@me"),
  kv("PR_MONITOR_MERGED_DAYS"; .monitors.merged_window_days // 2)
' <<<"$JSON")"

case "$MODE" in
  check) echo "load-config: $CONFIG is valid (stack.id $STACK_ID)";;
  stdout) printf '%s\n' "$ENV_TEXT";;
  write)
    mkdir -p "$(dirname "$OUT")"
    printf '%s\n' "$ENV_TEXT" >"$OUT.tmp.$$"
    mv "$OUT.tmp.$$" "$OUT"
    echo "load-config: wrote $OUT";;
esac
