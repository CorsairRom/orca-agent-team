# Tools

Three scripts that turn the stack configuration into running helpers for the Tech-lead:

| Script | What it does | Runs |
| --- | --- | --- |
| [`load-config.sh`](./load-config.sh) | Validates `config/stack.yaml` and writes the env file every other script reads | Once, and after every config change |
| [`pr-monitor.sh`](./pr-monitor.sh) | Polls the pull requests of every repository of the stack and sends the Tech-lead one line per change | In tmux, every 300 s by default |
| [`worker-watch.sh`](./worker-watch.sh) | Reads every live worker of the Tech-lead's Orca Run and tells the Tech-lead, once per prompt, when a worker waits on a permission prompt | In tmux, every 20 s by default |

The monitors only read GitHub and Orca. They write to their own state directory and send to the Tech-lead's Run
mailbox (or its terminal). They never approve, merge or answer anything. Where they fit in the whole setup: the
[setup guide](../docs/setup-guide.md); restarting them after a reboot: [reboot procedure](../docs/reboot.md).

## Requirements

| Dependency | Version | Used by | Check |
| --- | --- | --- | --- |
| `bash` | 4 or later | all | `bash --version` |
| `jq` | 1.6 or later | all | `jq --version` |
| `yq` (mikefarah/yq) | v4; tested with v4.54.1 | `load-config.sh` | `yq --version` → `yq (https://github.com/mikefarah/yq/) version v4.…` |
| `gh` | any current release, logged in with read access to every repository of the stack | `pr-monitor.sh` | `gh auth status` |
| Orca CLI | 1.4.245 or later, as `orca` (or `orca-ide`) | both monitors | `orca --version` |
| `tmux` | any | starting the monitors | `tmux -V` |
| GNU coreutils | `date -d`, `sha1sum` | both monitors | `date -d '-1 day'` |

Install `yq` v4 on Linux (x86_64; use `yq_linux_arm64` on ARM):

```bash
sudo curl -fsSL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.54.1/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
yq --version
```

On macOS, `brew install yq` installs the same tool; the monitors also need GNU `date`, which macOS does not ship
as `date`. Some Linux package managers ship a different, Python-based `yq` under the same name; the loader checks
`yq --version` and refuses anything but mikefarah/yq v4. To use a binary outside `PATH`, set `YQ_BIN`.

## Load the configuration

```bash
cp config/stack.example.yaml config/stack.yaml   # then edit it for your stack
tools/load-config.sh                             # → load-config: wrote ~/.local/share/<stack.id>/stack.env
```

`config/stack.yaml` describes your own stack, so keep it out of any public fork.

| Option | Default | Meaning |
| --- | --- | --- |
| `--config <file>` | `$STACK_CONFIG`, else `config/stack.yaml` next to `tools/` | Configuration to read |
| `--out <file>` | `$STACK_ENV_FILE`, else `~/.local/share/<stack.id>/stack.env` | Env file to write |
| `--stdout` | | Print the env file instead of writing it |
| `--check` | | Validate only; write nothing |

It exits `0` when the file is valid, `1` with one line per problem when it is not, and `2` when the configuration
or a dependency is missing. It checks: the required keys of every section, a `stack.id` matching `[a-z0-9-]+`,
every `repos[].kind` in `hub | frontend | backend | docs | infra | other`, exactly one `hub`, unique repository
names, `owner/repo` remotes, every model entry (`ideas`, `tech_lead`, `senior`, `mid`, `junior`) with an effort in
`low | medium | high | xhigh | max`, a `notify_mode` of `run` or `terminal` (and a terminal title for `terminal`),
and positive integer intervals. Every key and its meaning is documented in
[`config/stack.example.yaml`](../config/stack.example.yaml).

The env file is plain `KEY='value'` lines, safe to `source` from `bash`. A leading `~` in a repository path is
expanded to your home directory. It holds:

| Keys | Value |
| --- | --- |
| `STACK_ID`, `STACK_NAME`, `STACK_DIR` | The stack; `STACK_DIR` is `~/.local/share/<stack.id>` |
| `HUB_NAME`, `HUB_PATH`, `HUB_REMOTE`, `HUB_MAIN_BRANCH` | The repository of kind `hub` |
| `REPO_COUNT`, `REPO_<i>_NAME`, `REPO_<i>_PATH`, `REPO_<i>_REMOTE`, `REPO_<i>_MAIN_BRANCH`, `REPO_<i>_KIND` | Every repository, `<i>` from `0`, in config order |
| `PR_MONITOR_REPOS` | Space-separated `owner/repo` of every repository |
| `ENGRAM_PROJECT`, `TOPIC_PREFIX` | Shared memory |
| `LANG_OWNER_CONVERSATION`, `LANG_ARTIFACTS`, `LANG_APP_COPY`, `APP_COPY_RULES` | Languages; the app copy rules one per line |
| `MODEL_<ROLE>`, `EFFORT_<ROLE>` | Per role: `IDEAS`, `TECH_LEAD`, `SENIOR`, `MID`, `JUNIOR` |
| `ORCA_CHAT_UI`, `ORCA_AGENT_SLEEP`, `ORCA_AGENT_DASHBOARD` | The expected Orca settings, `true` or `false` |
| `IDEAS_DIR`, `TECH_LEAD_DIR` | `~/.local/share/<stack.id>-ideas`, `~/.local/share/<stack.id>-tech-lead` |
| `IDEAS_RUN_ID_FILE`, `TECH_LEAD_RUN_ID_FILE`, `RUN_ID_FILE` | `<dir>/run-id.txt`; `RUN_ID_FILE` is the Tech-lead's, the one the monitors send to |
| `NOTIFY_MODE`, `TECH_LEAD_TERMINAL_TITLE` | How the monitors reach the Tech-lead |
| `MONITOR_DIR` | `~/.local/share/<stack.id>/monitors`: state and logs of both monitors |
| `PR_INTERVAL_SECONDS`, `WATCH_INTERVAL_SECONDS`, `PR_MONITOR_AUTHOR`, `PR_MONITOR_MERGED_DAYS` | Monitor settings |

## How the monitors read their settings

Each monitor reads the env file named by `STACK_ENV_FILE`, when set. A variable already set in the environment
wins over the same key in the env file, and the script-specific variables in the tables below win over the
generic keys. Without `STACK_ENV_FILE` they run from plain environment variables alone. Every default is generic:
there is no built-in repository list, terminal title or Run id file, and a missing required value stops the
script with exit status `2` and a message naming the variable.

The monitors reach the Tech-lead in one of two notify modes:

| Mode | Delivery | For |
| --- | --- | --- |
| `run` (default) | An `orca orchestration send --to run:<id> --type status` message to the mailbox of the Run whose id is in `RUN_ID_FILE`, read on every send | A Tech-lead in an Orca chat bound to a Run: the default setup |
| `terminal` | Types the line into the Orca terminal titled `TECH_LEAD_TERMINAL_TITLE`, re-found by title on every send | A Tech-lead in a plain Orca terminal |

In `run` mode the message subject starts with `[PR monitor]` or `[Worker watch]`: the subject carries the source,
because the sender Orca shows for a process with no Orca identity is not reliable.

## Start

The Tech-lead writes its Run id once, from its own chat, after it creates its Run:

```bash
. ~/.local/share/acme/stack.env
mkdir -p "$TECH_LEAD_DIR"
orca orchestration run-current --json | jq -r '.result.run.id' > "$TECH_LEAD_RUN_ID_FILE"
```

`run-current` returns `.result.run` (`null` outside a coordinator); the `.id` field inside it is (unverified)
against the CLI help, which does not document the JSON shape. Check the file holds one id, not `null`.

Then it starts both monitors detached in tmux, so they survive its own session. Settings go inside the tmux
command, because an `export` in another shell does not reach a tmux session. The sessions are named
`<id>-pr-monitor` and `<id>-worker-watch`. With the example stack `acme` and this repository cloned at
`<team repo>`:

```bash
ENV_FILE=~/.local/share/acme/stack.env
tmux new-session -d -s acme-pr-monitor   "STACK_ENV_FILE=$ENV_FILE <team repo>/tools/pr-monitor.sh"
tmux new-session -d -s acme-worker-watch "STACK_ENV_FILE=$ENV_FILE <team repo>/tools/worker-watch.sh"
```

In `run` mode the worker watch takes no `<run_id>`: it watches the Run whose id is in `RUN_ID_FILE`, re-read on
every tick, so writing a new id there switches both monitors without a restart.

### Check them without sending anything

```bash
tmux ls                                                                   # → acme-pr-monitor and acme-worker-watch
STACK_ENV_FILE=~/.local/share/acme/stack.env <team repo>/tools/pr-monitor.sh --once     # → one JSON snapshot; sends nothing
STACK_ENV_FILE=~/.local/share/acme/stack.env <team repo>/tools/worker-watch.sh --once   # → one "tick" line per live worker; sends nothing
```

`--once` on the worker watch prints `tick no-run-id` while `RUN_ID_FILE` is missing or empty. A first run of the PR
monitor writes `state.json` and notifies nothing; it reports changes from the second poll on.

To prove the delivery path end to end, send one test line to the Tech-lead's mailbox (this one does send):

```bash
STACK_ENV_FILE=~/.local/share/acme/stack.env <team repo>/tools/pr-monitor.sh --notify "alive check"
tail -n 1 ~/.local/share/acme/monitors/monitor.log                       # → the orchestration send receipt
```

Expected: `[PR monitor] alive check` arrives in the Tech-lead's mailbox.

### `terminal` mode

Set `orca.notify_mode: terminal` and `orca.tech_lead_terminal_title` in the configuration, run the loader again,
and start the worker watch with the Run id as its first argument (in this mode it is required):

```bash
tmux new-session -d -s acme-pr-monitor   "STACK_ENV_FILE=$ENV_FILE <team repo>/tools/pr-monitor.sh"
tmux new-session -d -s acme-worker-watch "STACK_ENV_FILE=$ENV_FILE <team repo>/tools/worker-watch.sh <run_id>"
```

`<team repo>/tools/pr-monitor.sh --handle` prints the handle of the terminal it would type into; it must not be empty.

## Reference

### `pr-monitor.sh [interval_seconds] | --once | --handle | --notify <message> | --help`

| Variable | Fallback, then default | Meaning |
| --- | --- | --- |
| first argument | `PR_INTERVAL_SECONDS`, `300` | Seconds between polls |
| `PR_MONITOR_REPOS` | required | Space-separated `owner/repo` list it polls |
| `PR_MONITOR_AUTHOR` | `@me` | `gh pr list --author` filter: the PRs opened by the `gh` account |
| `PR_MONITOR_MERGED_DAYS` | `2` | A merged PR stays in the snapshot this many days |
| `PR_MONITOR_NOTIFY` | `NOTIFY_MODE`, `run` | `run` or `terminal`; any other value exits with status 2 |
| `PR_MONITOR_TITLE` | `TECH_LEAD_TERMINAL_TITLE` | `terminal` mode and `--handle`: title of the terminal it types into |
| `PR_MONITOR_DIR` | `MONITOR_DIR`, `~/.local/share/orca-agent-team/monitors` | Where `state.json`, `monitor.log` and `pending.txt` live |
| `RUN_ID_FILE` | `TECH_LEAD_RUN_ID_FILE` | `run` mode: the file holding the Run id it sends to |
| `ORCA_BIN` | `orca`, else `orca-ide` | Orca CLI |

What it watches: per repository, `gh pr list --author <author> --state all --limit 40`, keeping open PRs and PRs
merged within the window. It diffs each snapshot against `state.json` and sends one `[PR monitor] ...` line per
poll with every change: `NEW <repo>#<n> <state> -> <base>`, `state A->B`, `ready for review` / `back to draft`,
`review decision A->B`, `new review (<state>)`, `<n> new comment(s)`.

- `--once` prints one snapshot as JSON and exits; it sends nothing.
- `--handle` prints the handle of the terminal it would notify and exits.
- `--notify <message>` sends one line through the configured mode, the same way a change is sent, and exits.
- When the line cannot be delivered (no terminal with the title, or a missing or empty Run id file, or a failed
  send), it goes to `pending.txt` and is sent with the next change, prefixed `(delayed)`.
- `gh pr list --author` does not fail on a repository that does not exist or that `gh` cannot see: it returns no
  PRs. Check every `owner/repo` once with `gh repo view <owner/repo>`.

### `worker-watch.sh [<run_id> [interval_seconds]] | --once [<run_id>] | --help`

| Variable | Fallback, then default | Meaning |
| --- | --- | --- |
| first argument | `run` mode: the id in `RUN_ID_FILE` when empty or omitted; `terminal` mode: required | The Orca Run whose workers it watches |
| second argument | `WATCH_INTERVAL_SECONDS`, `20` | Seconds between ticks |
| `WORKER_WATCH_NOTIFY` | `NOTIFY_MODE`, `run` | `run` or `terminal`; any other value exits with status 2 |
| `WORKER_WATCH_TITLE` | `TECH_LEAD_TERMINAL_TITLE` | `terminal` mode: title of the terminal it types into |
| `WORKER_WATCH_DIR` | `MONITOR_DIR`, `~/.local/share/orca-agent-team/monitors` | Where `worker-watch.seen`, `worker-watch.log` and `worker-watch.ticks` live |
| `RUN_ID_FILE` | `TECH_LEAD_RUN_ID_FILE` | `run` mode: the file holding the Run id it sends to, and watches when no `<run_id>` is given |
| `ORCA_BIN` | `orca`, else `orca-ide` | Orca CLI |

Every tick it lists the Run's workers (`orca orchestration worker-list --run <run_id> --json`, status
`dispatched`) and reads each worker terminal (`orca terminal read --terminal <handle>`). A prompt is pending when
the last `[system] Allow` line has no later line starting with `resolved`, `denied`, `[assistant]` or
`[tool result]`. It notifies once per prompt, keyed by a hash of the dispatch id and the command, with
`[worker watch] <dispatch-id> is WAITING on a permission prompt (...): <command>`. The Tech-lead then reports the
command and its safety read to Ideas; the human decides.

It skips a worker whose terminal read fails, without logging it. A live worker with no line in
`worker-watch.ticks` is such a case: read it by hand with
`orca orchestration worker-read --dispatch <dispatch_id> --source auto`.

## Logs and state

All in `MONITOR_DIR` (or the `PR_MONITOR_DIR` / `WORKER_WATCH_DIR` override), outside every repository:

| File | Written by | Holds |
| --- | --- | --- |
| `state.json` | PR monitor | The last snapshot, the base of the next diff |
| `monitor.log` | PR monitor | Every change sent, every failed snapshot, the output of each send |
| `pending.txt` | PR monitor | Lines not delivered yet; emptied after a delayed send succeeds |
| `worker-watch.ticks` | worker watch | One line per worker per tick: `no-allow`, `allow-resolved` or `allow-PENDING`; `no-run-id` for a tick with no Run to watch; trimmed to 2000 lines |
| `worker-watch.log` | worker watch | Every notification and the output of each send, including a failed or skipped send |
| `worker-watch.seen` | worker watch | Keys of prompts already notified |

## Stop and restart

```bash
tmux kill-session -t acme-pr-monitor
tmux kill-session -t acme-worker-watch
```

Both die on reboot and nothing restarts them: the Tech-lead restarts them with the start commands above, as part
of the [reboot procedure](../docs/reboot.md). After a configuration change, run `tools/load-config.sh` again and
restart both. A new Tech-lead Run needs no restart in `run` mode: writing its id to `RUN_ID_FILE` is enough.
Keeping `state.json` across a restart avoids a burst of `NEW` lines.

## Continuous integration

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull request and on every push to `main`
or to an `integration/**` branch:

- **shellcheck** v0.11.0 and `bash -n` on `tools/*.sh`. Run them locally with `shellcheck tools/*.sh`.
- **Example config**: `load-config.sh` validates `config/stack.example.yaml` with yq v4.54.1 and the generated env
  file is sourced; both monitors print their `--help`.
- shellcheck and yq are downloaded from their releases and checked against pinned SHA-256 sums; actions are pinned
  to commits. The workflow uses no secrets.
- **Markdown links**: lychee, through `lycheeverse/lychee-action` pinned to a commit, checks every link in
  `*.md` offline: relative paths and anchors inside the repository, not external URLs.
