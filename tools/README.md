# Tools

Two monitors that run beside the Tech-lead, and the env file they read:

| Piece | What it does | Runs |
| --- | --- | --- |
| [The env file](#writing-the-env-file) | `<team dir>/stack.env`, one per [team](#teams): every value of `config/stack.yaml` a bash step needs, as `KEY='value'` lines, plus the conventions file the Tech-lead passes into briefs. The chats and the monitors source it; some keys, such as `MODEL_*`, `PROVIDER_*`, `LANG_*` and `DELIVERY_*`, only the chats read. A chat writes it from the config; nothing parses the YAML locally | Once at install, and after every config change |
| [`pr-monitor.sh`](./pr-monitor.sh) | Polls the pull requests of every repository of the stack and sends the Tech-lead one line per change | In tmux, every 300 s by default |
| [`worker-watch.sh`](./worker-watch.sh) | Reads Orca's observation of every live worker of the Tech-lead's Orca Run and tells the Tech-lead, once per prompt or error, when a worker waits on a prompt only a human can answer, stopped on a usage-limit error, or cannot be observed | In tmux, every 20 s by default |

The monitors only read GitHub and Orca. They write to their own state directory and send to the mailbox of the
Tech-lead's Orca Run. They never approve, merge or answer anything. Where they fit in the whole setup: the
[setup guide](../docs/setup-guide.md); restarting them after a reboot: [reboot procedure](../docs/reboot.md).

## Requirements

The minimum versions are in the [README](../README.md#prerequisites).

| Dependency | Notes | Used by | Check |
| --- | --- | --- | --- |
| `bash` | | all | `bash --version` |
| `jq` | | all | `jq --version` |
| `gh` | Logged in with read access to every repository of the stack | `pr-monitor.sh` | `gh auth status` |
| Orca CLI | As `orca` (or `orca-ide`) | both monitors | `orca --version` |
| `tmux` | Its `new-session` takes `-e` (`man tmux`) | starting the monitors | `tmux -V` |
| `sha1sum` or `shasum` | Either one; Linux ships `sha1sum`, macOS ships `shasum` | `worker-watch.sh` | `command -v sha1sum shasum` |

The monitors use only POSIX `date` and `jq` for timestamps and date math, so they need no GNU tools on macOS. No
YAML parser is needed: the chat that writes the env file reads the config itself.

## Writing the env file

This section is an instruction for a Claude Code chat: the installing chat in step 3 of
[`BOOTSTRAP_PROMPT.md`](../BOOTSTRAP_PROMPT.md#step-3-write-the-env-file), or Ideas or the Tech-lead when the
product owner asks them after a config change ([README](../README.md#configuring-the-stack)). It is the only
description of the env file; every other file links here. `config/stack.yaml` describes your own stack, so keep
it out of any public fork.

**1. Read.** Read `<team repo>/config/stack.yaml` whole with the file tool. Do not use a YAML parser. Every key and
its meaning is documented in [`config/stack.example.yaml`](../config/stack.example.yaml). Find `<home>` with
`echo "$HOME"`; a test run may use a scratch directory as `<home>` instead, and then writes everything below it.
Find `<team id>`: the team id the install prompt names, or `TEAM_ID` in the env file you are rewriting; empty for
the default team ([teams](#teams)).

**2. Validate.** Check every rule below and collect every problem, each as `<key>: <what is wrong>`, such as
`repos[1].kind: one of hub | frontend | backend | docs | infra | other`. A boolean is an unquoted `true` or
`false`; a quoted `"true"` is a string. An integer is unquoted and has no decimals.

| Key | Rule |
| --- | --- |
| the file | A YAML mapping |
| `<team id>` | Empty, or lowercase letters, digits and hyphens only (`[a-z0-9-]+`) |
| `stack.id` | Required; lowercase letters, digits and hyphens only (`[a-z0-9-]+`) |
| `stack.name` | Required; a non-empty string |
| `repos` | Required; a non-empty list of mappings; exactly one entry with `kind: hub`; no two entries with the same `name` |
| `repos[i].name`, `.path`, `.main_branch` | Required; non-empty strings |
| `repos[i].remote` | Required; a GitHub `owner/repo`, matching `[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+` |
| `repos[i].kind` | Required; one of `hub`, `frontend`, `backend`, `docs`, `infra`, `other` |
| `hub` | Optional mapping; `prds_dir`, `decisions_dir` and `backlog_file` are optional paths relative to the hub repository: not starting with `/` or `~` |
| `delivery` | Optional mapping; `integration_branch_per_feature` and `owner_merges_main` are optional booleans |
| `conventions` | Optional; a list of non-empty strings, each on one line |
| `memory.engram_project`, `memory.topic_prefix` | Required; non-empty strings |
| `language.owner_conversation`, `.artifacts`, `.app_copy` | Required; non-empty strings |
| `language.app_copy_rules` | Optional; a list of strings |
| `models.<role>.model` | Required for each of `ideas`, `tech_lead`, `senior`, `mid`, `junior`; a non-empty string, a Claude Code model id |
| `models.<role>.effort` | Required for the same five; one of `low`, `medium`, `high`, `xhigh`, `max` |
| `providers` | Optional; a list of mappings; no two entries with the same `agent`. Absent or `[]` means every worker is Claude |
| `providers[i].agent` | Required; an Orca agent id matching `[a-z0-9-]+`, not `claude` |
| `providers[i].model` | Required; a string, possibly empty (`""`) |
| `providers[i].takes` | Required; a non-empty list, each entry one of `explore`, `docs-draft`, `mechanical` |
| `orca.chat_ui`, `orca.agent_sleep`, `orca.agent_dashboard` | Optional booleans |
| `monitors.pr_interval_seconds`, `monitors.watch_interval_seconds` | Optional integers, 1 or more |
| `monitors.pr_author` | Optional; a non-empty string |
| `monitors.merged_window_days` | Optional integer, 0 or more |

If there is any problem, write nothing. Tell the human every problem in one message, fix them in
`config/stack.yaml` with the human, and start again from step 1.

**3. Write.** With the editor tool, write `<TEAM_DIR>/stack.env` (table below): a first line
`# Written from <team repo>/config/stack.yaml by a chat; edit the config, not this file.`, then one `KEY='value'`
line per key, in the order of the table below. Every value is in single quotes; a `'` inside a value is written
`'\''`. Write every path absolute: `<home>` instead of a leading `~`, both in the derived paths and in `repos[].path`.
`<i>` counts the repositories, and the providers, from `0`, in config order. An optional key that is missing
takes the default shown.
Every derived path lies in the team's tree, `TEAM_DIR`, inside the stack's local-share tree
`<home>/.local/share/<stack.id>/` ([durable folders](../docs/setup-guide.md#durable-folders)). The placeholder each key stands for in the docs, and
who fills it, is in the [placeholder table](../agents/README.md#placeholders).

| Keys | Value |
| --- | --- |
| `STACK_ID`, `STACK_NAME` | `stack.id`, `stack.name` |
| `STACK_DIR` | `<home>/.local/share/<stack.id>` |
| `TEAM_ID` | `<team id>`; empty for the default team |
| `TEAM_DIR` | `<STACK_DIR>` for the default team; `<STACK_DIR>/teams/<team id>` for a named team |
| `STACK_ENV_FILE` | `<TEAM_DIR>/stack.env`: this file |
| `BOOTSTRAP_DIR` | `<TEAM_DIR>/bootstrap`: the installing chat's folder |
| `TEAM_REPO` | The absolute path of this repository's clone, the one whose `config/stack.yaml` you read |
| `HUB_NAME`, `HUB_PATH`, `HUB_REMOTE`, `HUB_MAIN_BRANCH` | `name`, `path`, `remote` and `main_branch` of the repository of kind `hub` |
| `HUB_PRDS_DIR`, `HUB_DECISIONS_DIR`, `HUB_BACKLOG_FILE` | `hub.prds_dir`, `hub.decisions_dir`, `hub.backlog_file`, relative to `HUB_PATH`; default `docs/prd`, `docs/decisions`, `BACKLOG.md`. A named team inserts `-<team id>` before the extension of the backlog file, such as `BACKLOG-<team id>.md`: each Tech-lead is the only writer of its own backlog |
| `DELIVERY_INTEGRATION_BRANCH_PER_FEATURE`, `DELIVERY_OWNER_MERGES_MAIN` | `delivery.integration_branch_per_feature`, `delivery.owner_merges_main`: `true` or `false`; default `true` |
| `REPO_COUNT` | The number of entries of `repos` |
| `REPO_<i>_NAME`, `REPO_<i>_PATH`, `REPO_<i>_REMOTE`, `REPO_<i>_MAIN_BRANCH`, `REPO_<i>_KIND` | The five keys of `repos[<i>]`, for every `<i>` from `0` to `REPO_COUNT - 1` |
| `PR_MONITOR_REPOS` | Every `repos[].remote`, space-separated, in config order, each once |
| `ENGRAM_PROJECT`, `TOPIC_PREFIX` | `memory.engram_project`, `memory.topic_prefix` |
| `LANG_OWNER_CONVERSATION`, `LANG_ARTIFACTS`, `LANG_APP_COPY` | `language.owner_conversation`, `.artifacts`, `.app_copy` |
| `APP_COPY_RULES` | `language.app_copy_rules`, one rule per line inside the quotes; default empty |
| `MODEL_<ROLE>`, `EFFORT_<ROLE>` | `models.<role>.model` and `.effort`, for `<ROLE>` `IDEAS`, `TECH_LEAD`, `SENIOR`, `MID`, `JUNIOR` (`models.ideas`, `models.tech_lead`, `models.senior`, `models.mid`, `models.junior`) |
| `PROVIDER_COUNT` | The number of entries of `providers`; default `0` |
| `PROVIDER_<i>_AGENT`, `PROVIDER_<i>_MODEL`, `PROVIDER_<i>_TAKES` | `agent`, `model` and `takes` of `providers[<i>]`, for every `<i>` from `0` to `PROVIDER_COUNT - 1`; `takes` space-separated, in config order |
| `ORCA_CHAT_UI`, `ORCA_AGENT_SLEEP`, `ORCA_AGENT_DASHBOARD` | `orca.chat_ui`, `orca.agent_sleep`, `orca.agent_dashboard`; default `true`, `false`, `true` |
| `IDEAS_DIR`, `TECH_LEAD_DIR` | `<TEAM_DIR>/ideas`, `<TEAM_DIR>/tech-lead`: the durable folders of Ideas and the Tech-lead |
| `IDEAS_WORKTREE_NAME`, `TECH_LEAD_WORKTREE_NAME` | `Ideas` and `Tech-lead` for the default team; `Ideas-<team id>` and `Tech-lead-<team id>` for a named team: the names of the two hub worktrees |
| `IDEAS_RUN_ID_FILE`, `TECH_LEAD_RUN_ID_FILE` | `<IDEAS_DIR>/run-id.txt`, `<TECH_LEAD_DIR>/run-id.txt` |
| `RUN_ID_FILE` | The same as `TECH_LEAD_RUN_ID_FILE`: the Run the monitors send to |
| `CONVENTIONS_FILE` | `<TECH_LEAD_DIR>/conventions.txt` |
| `MONITOR_DIR` | `<TEAM_DIR>/monitors`: state and logs of both monitors; the monitors stop without it |
| `TMUX_PREFIX` | `<stack.id>` for the default team; `<stack.id>-<team id>` for a named team: the monitors run in the tmux sessions `<TMUX_PREFIX>-pr-monitor` and `<TMUX_PREFIX>-worker-watch` |
| `INVENTORY_TOPIC` | `<prefix>/agents/tech-lead-inventory` for the default team; `<prefix>/agents/<team id>/tech-lead-inventory` for a named team: the Engram topic of the Tech-lead's inventory |
| `PR_MONITOR_BRANCHES_FILE` | `<TECH_LEAD_DIR>/branches.txt`: the team's integration branches; when the file exists, the PR monitor reports only their PRs ([teams](#teams)) |
| `PR_INTERVAL_SECONDS`, `WATCH_INTERVAL_SECONDS` | `monitors.pr_interval_seconds`, `monitors.watch_interval_seconds`; default `300`, `20` |
| `PR_MONITOR_AUTHOR`, `PR_MONITOR_MERGED_DAYS` | `monitors.pr_author`, `monitors.merged_window_days`; default `@me`, `2` |

Then write the conventions file, `CONVENTIONS_FILE`: the `conventions` list, one convention per line, without
quotes; an empty file when the list is empty or missing. The Tech-lead pastes its lines into every brief.

**4. Read back.** Run, with the path you wrote:

```bash
bash -c 'set -eu; . "$1"; for k in STACK_ID TEAM_ID STACK_DIR TEAM_DIR STACK_ENV_FILE BOOTSTRAP_DIR TEAM_REPO HUB_PATH HUB_MAIN_BRANCH HUB_BACKLOG_FILE REPO_COUNT MODEL_IDEAS EFFORT_IDEAS MODEL_TECH_LEAD EFFORT_TECH_LEAD PROVIDER_COUNT IDEAS_DIR TECH_LEAD_DIR IDEAS_WORKTREE_NAME TECH_LEAD_WORKTREE_NAME IDEAS_RUN_ID_FILE TECH_LEAD_RUN_ID_FILE RUN_ID_FILE CONVENTIONS_FILE MONITOR_DIR TMUX_PREFIX INVENTORY_TOPIC PR_MONITOR_BRANCHES_FILE; do printf "%s=%s\n" "$k" "${!k}"; done
  for ((i = 0; i < REPO_COUNT; i++)); do p="REPO_${i}_PATH"; r="REPO_${i}_REMOTE"; k="REPO_${i}_KIND"; printf "%s %s %s\n" "${!k}" "${!r}" "${!p}"; done
  for ((i = 0; i < PROVIDER_COUNT; i++)); do a="PROVIDER_${i}_AGENT"; m="PROVIDER_${i}_MODEL"; t="PROVIDER_${i}_TAKES"; printf "provider %s model=%s takes=%s\n" "${!a}" "${!m}" "${!t}"; done
  cat "$CONVENTIONS_FILE"' _ <TEAM_DIR>/stack.env
```

**Expected:** the file sources with no error; every value matches `config/stack.yaml` and `<team id>`; every path
is absolute and lies under `TEAM_DIR`, except `TEAM_REPO`, `HUB_PATH` and the repositories; one line per
repository and one per provider; the conventions file holds the `conventions` list. On a mismatch, fix the
file and read it back again. Then show the human the output.

Edit the configuration, not these two files: they are written again after every config change.

An env file written before [teams](#teams) existed lacks `TEAM_ID`, `TEAM_DIR`, `TMUX_PREFIX` and the other
per-team keys. Write it again, with an empty `<team id>`, before the next resume: the checklists check for `TEAM_DIR`.

## How the monitors read their settings

Each monitor reads the env file named by `STACK_ENV_FILE`. A variable already set in the environment wins over the
same key in the env file, and the script-specific variables in the tables below win over the generic keys. Every
default is generic: there is no built-in repository list, Run id file or state directory. A missing
`STACK_ENV_FILE`, an env file that sets no `MONITOR_DIR`, or any other missing required value stops the script with
exit status `2` and a message naming the variable. `--help` needs none of them.

Both monitors reach the Tech-lead the same way: an `orca orchestration send --to run:<id> --type status` message to
the mailbox of the Run whose id is in `RUN_ID_FILE`, read again on every send. The subject starts with
`[PR monitor]` or `[Worker watch]`: the subject carries the source. The sender Orca records is the identity the
tmux session was started with, the Tech-lead's ([Start](#start);
[gotchas](../docs/gotchas.md#a-tmux-session-sends-under-the-identity-it-was-started-with)).

## Start

The Tech-lead chat writes its Run id file in its first turn, from its own chat, after it creates its Run (its
after-start checklist does this):

```bash
. ~/.local/share/acme/stack.env
mkdir -p "$TECH_LEAD_DIR"
orca orchestration run-current --json | jq -r '.result.run.id' > "$TECH_LEAD_RUN_ID_FILE"
```

`run-current` returns `.result.run` (`null` outside a coordinator); the `.id` field inside it is (unverified)
against the CLI help, which does not document the JSON shape. Check the file holds one id, not `null`.

The Tech-lead chat starts both monitors, detached in tmux, so they outlive its process. It starts them, not the
installing chat, because a monitor sends under the Orca identity of the chat that started it, and the installing
chat is closed after the install. They may start before the Run id file exists: until it does, the PR monitor keeps
its lines in `pending.txt` and the worker watch ticks `no-run-id`.

A tmux session takes its environment from the tmux server, which holds the environment of whoever started the
server, possibly another chat ([gotchas](../docs/gotchas.md#a-tmux-session-sends-under-the-identity-it-was-started-with)).
So the start lines pass every `ORCA_*` variable of the starting chat with `tmux new-session -e`, and the settings
go inside the tmux command, because an `export` in another shell does not reach a tmux session. The sessions are
named `<TMUX_PREFIX>-pr-monitor` and `<TMUX_PREFIX>-worker-watch`. With the example stack `acme`, these lines stop any
copy already running and start both; every value comes from the env file. They need bash, so they run as
`bash -c '...'` whatever the chat's shell is:

```bash
bash -c '
. ~/.local/share/acme/stack.env
orca_env=(); while IFS= read -r v; do orca_env+=(-e "$v"); done < <(env | grep "^ORCA_")
tmux kill-session -t "$TMUX_PREFIX-pr-monitor" 2>/dev/null; tmux kill-session -t "$TMUX_PREFIX-worker-watch" 2>/dev/null
tmux new-session -d -s "$TMUX_PREFIX-pr-monitor"   "${orca_env[@]}" "STACK_ENV_FILE=\"$STACK_ENV_FILE\" \"$TEAM_REPO/tools/pr-monitor.sh\""
tmux new-session -d -s "$TMUX_PREFIX-worker-watch" "${orca_env[@]}" "STACK_ENV_FILE=\"$STACK_ENV_FILE\" \"$TEAM_REPO/tools/worker-watch.sh\""
tmux ls
'
```

Started without a `<run_id>`, the worker watch watches the Run whose id is in `RUN_ID_FILE`, re-read on every tick,
so writing a new id there switches both monitors without a restart.

### Check them without sending anything

```bash
. ~/.local/share/acme/stack.env
tmux ls                                                                  # → acme-pr-monitor and acme-worker-watch
STACK_ENV_FILE="$STACK_ENV_FILE" "$TEAM_REPO/tools/pr-monitor.sh" --once      # → one JSON snapshot; sends nothing
STACK_ENV_FILE="$STACK_ENV_FILE" "$TEAM_REPO/tools/worker-watch.sh" --once    # → one "tick" line per live worker; sends nothing
```

`--once` on the worker watch prints `tick no-run-id` while `RUN_ID_FILE` is missing or empty. A first run of the PR
monitor writes `state.json` and notifies nothing; it reports changes from the second poll on.

### The alive check

To prove the delivery path end to end, send one test line to the Tech-lead's mailbox from inside the PR monitor's
tmux session, so it carries the session's identity (this one does send):

```bash
. ~/.local/share/acme/stack.env
tmux new-window -d -t "$TMUX_PREFIX-pr-monitor" "STACK_ENV_FILE=\"$STACK_ENV_FILE\" \"$TEAM_REPO/tools/pr-monitor.sh\" --notify 'alive check'"
sleep 5; tail -n 1 "$MONITOR_DIR/monitor.log"                             # → the orchestration send receipt
```

Expected: `[PR monitor] alive check` arrives in the Tech-lead's mailbox.

### Check the sender

The alive check must carry the Tech-lead's identity. Compare its sender with the sender of the Tech-lead's own
`[Tech-lead] ready` message:

```bash
orca orchestration inbox --limit 100 --json | jq -r '[.. | objects | select(has("from_handle") and has("subject"))] | unique_by(.id) | sort_by(.created_at)[] | select((.subject | startswith("[PR monitor] alive check")) or (.subject | startswith("[Tech-lead] ready"))) | "\(.created_at)  \(.from_handle)  \(.subject)"'
```

Expected: the newest alive check and the newest `[Tech-lead] ready` show the same `from_handle`. Another sender
means the sessions carry another chat's identity: the Tech-lead starts them again with the start lines above. A send
refused with `no_active_sender_terminal` means the session has no live Orca identity at all `(unverified)`. Whether a
Tech-lead identity still sends after the Chat UI's idle sweep has stopped its process is `(unverified)`; the
Tech-lead's checklist restarts the monitors on every resume, and the alive check tells.

## Reference

### `pr-monitor.sh [interval_seconds] | --once | --notify <message> | --help`

| Variable | Fallback, then default | Meaning |
| --- | --- | --- |
| `STACK_ENV_FILE` | required | The env file it reads |
| first argument | `PR_INTERVAL_SECONDS`, `300` | Seconds between polls |
| `PR_MONITOR_REPOS` | required | Space-separated `owner/repo` list it polls |
| `PR_MONITOR_AUTHOR` | `@me` | `gh pr list --author` filter: the PRs opened by the `gh` account |
| `PR_MONITOR_MERGED_DAYS` | `2` | A merged PR stays in the snapshot this many days |
| `PR_MONITOR_BRANCHES_FILE` | none | When set and the file exists, only PRs whose base or head branch is a line of the file are kept |
| `MONITOR_DIR` | required | Where `state.json`, `monitor.log` and `pending.txt` live |
| `RUN_ID_FILE` | `TECH_LEAD_RUN_ID_FILE` | The file holding the Run id it sends to; required except with `--once` |
| `ORCA_BIN` | `orca`, else `orca-ide` | Orca CLI |

What it watches: per repository, `gh pr list --author <author> --state all --limit 40`, keeping open PRs and PRs
merged within the window, and, when `PR_MONITOR_BRANCHES_FILE` names an existing file, only the PRs whose base or
head branch is listed in it ([teams](#teams)). It diffs each snapshot against `state.json` and sends one `[PR monitor] ...` line per
poll with every change: `NEW <repo>#<n> <state> -> <base>`, `state A->B`, `ready for review` / `back to draft`,
`review decision A->B`, `new review (<state>)`, `<n> new comment(s)`.

- `--once` prints one snapshot as JSON and exits; it sends nothing.
- `--notify <message>` sends one line to the Tech-lead's Run, the same way a change is sent, and exits.
- When the line cannot be delivered (a missing or empty Run id file, or a failed send), it goes to `pending.txt`
  and is sent with the next change, prefixed `(delayed)`.
- `gh pr list --author` does not fail on a repository that does not exist or that `gh` cannot see: it returns no
  PRs `(unverified)`. Check every `owner/repo` once with `gh repo view <owner/repo>`.

### `worker-watch.sh [<run_id> [interval_seconds]] | --once [<run_id>] | --help`

| Variable | Fallback, then default | Meaning |
| --- | --- | --- |
| `STACK_ENV_FILE` | required | The env file it reads |
| first argument | the id in `RUN_ID_FILE` when empty or omitted | The Orca Run whose workers it watches |
| second argument | `WATCH_INTERVAL_SECONDS`, `20` | Seconds between ticks |
| `MONITOR_DIR` | required | Where `worker-watch.seen`, `worker-watch.log` and `worker-watch.ticks` live |
| `RUN_ID_FILE` | `TECH_LEAD_RUN_ID_FILE` | The file holding the Run id it sends to, and watches when no `<run_id>` is given; required except with `--once <run_id>` |
| `WATCH_LIMIT_PATTERNS` | none | Newline-separated extended regexes of usage-limit errors, matched case-insensitively and added to the defaults below |
| `ORCA_BIN` | `orca`, else `orca-ide` | Orca CLI |

Every tick it lists the Run's workers (`orca orchestration worker-list --run <run_id> --json`, status
`dispatched`) and reads Orca's own observation of each one, `.result.observation.agentWait` of
`orca orchestration worker-show --dispatch <dispatch-id> --json`. `worker-show --help` defines it: a value names a
worker parked on a prompt only a human can answer, with the evidence; `null` means Orca looked and found no wait;
an absent field means Orca did not look, which never means the worker is not waiting. The shape of a non-null value
is `(unverified)`; the watch passes it on as compact JSON.

- `agentWait` set: it notifies once per wait, keyed by a hash of the dispatch id and the value, with
  `[worker watch] <dispatch-id> is WAITING on a prompt only a human can answer: <agentWait>`.
- `agentWait` absent: it falls back to `orca orchestration worker-read --dispatch <dispatch-id> --source auto`,
  keeps the newest two pages, and looks for a `[system] Allow` line with no later line starting with `resolved`,
  `denied`, `[assistant]` or `[tool result]`; it then notifies once per prompt with
  `[worker watch] <dispatch-id> is WAITING on a permission prompt (...): <command>`. Whether a transcript source
  shows permission prompts this way is `(unverified)`. Between ticks it keeps the cursor of the last page it read,
  because the cursor after the newest page is refused as invalid `(unverified)`.
- Usage limit, on every tick for every live worker, whichever path above ran: it reads the worker's newest two pages
  with `worker-read --source auto` and looks for a line matching a default or a `WATCH_LIMIT_PATTERNS` pattern. It
  notifies once per worker and line with `[worker watch] <dispatch-id> stopped on a usage limit: <the matched line,
  200 characters at most>`, and ticks `limit-HIT`. It reports the error and changes nothing; the Tech-lead
  re-dispatches the unit on another provider ([providers](../docs/providers.md)). A line that only quotes a pattern,
  such as a transcript of a worker editing this script, also matches.
- Neither works: it never skips the worker silently. It ticks `unobservable` and notifies once per dispatch with
  `[worker watch] <dispatch-id> cannot be observed ...` and the `worker-read` line to read it by hand.

The watch only sees workers that are alive at a tick, and that is enough: a worker parked on a prompt stays alive,
so a later tick always sees it. A worker that starts and finishes between two ticks is never ticked, and needs no
watch. On the minimum Orca version, `worker-show` gives no `agentWait` field for a running worker, so the
`worker-read` fallback is the path that runs; whether `agentWait` appears for a parked worker is `(unverified)`.

Default usage-limit patterns, extended regexes, matched case-insensitively:

| Pattern | Source |
| --- | --- |
| `provider\.free-limit` | OpenCode 2.2.2, free model out of quota |
| `Free usage limit reached` | OpenCode 2.2.2, free model out of quota |
| `usage limit reached` | OpenCode 2.2.2 (OpenCode Go) |
| `hit your (usage )?limit` | Claude Code `(unverified)` |
| `RESOURCE_EXHAUSTED`, `Quota exceeded` | Gemini quota errors `(unverified)` |

Set `WATCH_LIMIT_PATTERNS` in the env file as a multi-line value, one regex per line; blank lines are ignored.

The Tech-lead then reports the prompt and its safety read to Ideas; the human decides.

## Logs and state

All in `MONITOR_DIR`, `<team dir>/monitors`, outside every repository:

| File | Written by | Holds |
| --- | --- | --- |
| `state.json` | PR monitor | The last snapshot, the base of the next diff |
| `monitor.log` | PR monitor | Every change sent, every failed snapshot, the output of each send |
| `pending.txt` | PR monitor | Lines not delivered yet; emptied after a delayed send succeeds |
| `worker-watch.ticks` | worker watch | One line per worker per tick: `no-wait` or `wait-PENDING` from `agentWait`; `no-allow`, `allow-resolved` or `allow-PENDING` from the fallback; `limit-HIT` for a worker whose rows match a usage-limit pattern, besides one of the others; `unobservable`; `no-run-id` for a tick with no Run to watch; trimmed to 2000 lines |
| `worker-watch.cursor.<dispatch-id>`, `worker-watch.tail.<dispatch-id>` | worker watch | The fallback's last cursor and newest rows of one worker |
| `worker-watch.log` | worker watch | Every notification and the output of each send, including a failed or skipped send |
| `worker-watch.seen` | worker watch | Keys of prompts already notified |

## Stop and restart

```bash
tmux kill-session -t acme-pr-monitor
tmux kill-session -t acme-worker-watch
```

A named team's sessions carry its `TMUX_PREFIX`, such as `acme-billing-pr-monitor`.

Both die on reboot and nothing restarts them: the Tech-lead restarts them with the start commands above, as part
of the [reboot procedure](../docs/reboot.md). After a configuration change, follow
[Configuring the stack](../README.md#configuring-the-stack) in the README. A new Tech-lead Run needs no restart: writing its id to `RUN_ID_FILE` is enough.
Keeping `state.json` across a restart avoids a burst of `NEW` lines.

## Teams

One stack can run several teams at once, each with its own Ideas, Tech-lead, Runs, monitors and backlog, so that
two large features do not share one product-owner queue or one Tech-lead context
([setup guide](../docs/setup-guide.md#several-teams-on-one-stack)). A team is chosen when its env file is written:

- **The default team** has an empty `<team id>`. Its paths, worktree names and tmux sessions are the ones every
  example in these docs shows.
- **A named team** has a `<team id>` such as `billing`. Everything that belongs to one team is derived from it:
  `TEAM_DIR`, the worktree names, `TMUX_PREFIX`, `INVENTORY_TOPIC` and the backlog file. The stack's
  `config/stack.yaml`, the Engram project and the hub's PRD and decision folders stay shared.

The PR monitor polls with `--author`, which is the same `gh` account for every team. So a Tech-lead that is not
alone on the stack keeps `PR_MONITOR_BRANCHES_FILE`: the feature branches its PRs target or come from, one per
line. A named team's Tech-lead creates the file, empty, on its first start; while it is empty, its monitor reports
nothing. A team whose file does not exist sees every PR of the account, as before.

## Continuous integration

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull request and on every push to `main`:

- **shellcheck** v0.11.0 and `bash -n` on `tools/*.sh`. Run them locally with `shellcheck tools/*.sh`.
- **Example config**: yq v4.54.1, downloaded on the runner only, checks that `config/stack.example.yaml` parses,
  has exactly one repository of kind `hub`, and has every key the [env file table](#writing-the-env-file) maps.
  It also checks `providers`: each entry has `agent`, `model` and `takes`, and every `takes` value is one of
  `explore`, `docs-draft` and `mechanical`.
  Nothing validates a config locally: the chat that writes the env file does.
- **Monitors**: both print their `--help`.
- shellcheck and yq are downloaded from their releases and checked against pinned SHA-256 sums; actions are pinned
  to commits. The workflow uses no secrets.
- **Markdown links**: lychee, through `lycheeverse/lychee-action` pinned to a commit, checks every link in
  `*.md` offline: relative paths and anchors inside the repository, not external URLs.
