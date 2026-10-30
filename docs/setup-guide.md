# Setup guide

How to build the agent team on a machine, with the reasons behind each step: the Ideas chat, the Tech-lead chat and
its workers, the monitors, the memory, and how a feature runs from a request to the integration PRs.
[`BOOTSTRAP_PROMPT.md`](../BOOTSTRAP_PROMPT.md) executes the same build as checkable steps; this guide is the
reference it relies on.

The rules themselves live in the documents below, and those win where they say more:

| Document | Holds |
| --- | --- |
| [`agents/README.md`](../agents/README.md) | The operating manual: lifecycle, roles, delivery, quick path |
| [`agents/team-conventions.md`](../agents/team-conventions.md) | Rules for everything an agent writes |
| [`agents/roles/`](../agents/roles/) | One card per role: [Ideas](../agents/roles/ideas/SKILL.md), the [Tech-lead](../agents/roles/tech-lead/SKILL.md), the [reviewer](../agents/roles/reviewer/SKILL.md), [QA](../agents/roles/qa/SKILL.md) and one developer card per repository kind |
| [`agents/templates/`](../agents/templates/) | PRD, brief, worker report, test plan, and the after-start checklists of [Ideas](../agents/templates/after-start-ideas.md) and the [Tech-lead](../agents/templates/after-start-tech-lead.md) |
| [`tools/README.md`](../tools/README.md) | The config loader, the PR monitor and the permission watch |
| [`docs/delivery-model.md`](./delivery-model.md) | Integration branches, work-unit PRs, who merges, gentle-ai |
| [`docs/gotchas.md`](./gotchas.md) | Known gotchas |
| [`docs/reboot.md`](./reboot.md) | Reboot and reopen |

Scope: **chat mode**. Ideas and the Tech-lead are Claude Code sessions in Orca chats (Chat UI on), each the
top-level coordinator of its own Run, and they talk only through those Runs' mailboxes. The `orca` commands were
checked against `--help` on Orca 1.4.245; anything not run end to end is marked `(unverified)`.

## Placeholders

| Placeholder | Meaning |
| --- | --- |
| `<id>` | `stack.id` from `config/stack.yaml`, for example `acme` |
| `<hub>` | The local path of the repository with `kind: hub` (`$HUB_PATH` in the env file) |
| `<Ideas>`, `<Tech-lead>` | Absolute paths of the two hub worktrees Orca creates |
| `<role dir>` | A coordinator's durable folder: `~/.local/share/<id>-ideas/` or `~/.local/share/<id>-tech-lead/` |
| `<own run id>`, `<peer run-id file>` | A coordinator's own Run id, read from its own `<role dir>/run-id.txt`, and the other coordinator's Run id file |
| `<file>` | A message body file in the sender's durable folder, never under `/tmp` |
| `<dispatch-id>`, `<task-id>` | A worker's ids, from the JSON `worker-start` prints or from `orca orchestration worker-list --json` |

## What you are building

```
product owner ── talks only to Ideas
 └─ Ideas · Claude Code in an Orca chat, hub worktree «Ideas»
      ├─ its own Run: a mailbox, id in ~/.local/share/<id>-ideas/run-id.txt
      ├─ its own Claude subagents: read-only research
      └─ Run-to-Run mail (orca orchestration send --to run:<peer run id>), never a worker relation
          └─ Tech-lead · Claude Code in an Orca chat, hub worktree «Tech-lead», a child worktree of «Ideas»
               ├─ its own standing Run, reused across features, id in ~/.local/share/<id>-tech-lead/run-id.txt:
               │    workers started with worker-start --worktree new-child, one worktree per work unit
               ├─ tmux: PR monitor        → PR changes to the Tech-lead's Run mailbox
               └─ tmux: permission watch  → pending permission prompts to the Tech-lead's Run mailbox
Shared memory: Engram, project memory.engram_project, read and written by every chat
```

**Why two coordinators.** The Tech-lead cannot be a dispatched worker of Ideas: Orca's nesting depth is 1, and a
worker that starts its own worker is refused ([gotchas](./gotchas.md#nesting-depth-is-1)). So both are top-level
coordinators with their own Runs, and they talk Run to Run.

## Prerequisites

The tools and their tested versions are in the [README](../README.md#prerequisites). How to get the ones that need
more than a package manager:

| Need | Check | If missing |
| --- | --- | --- |
| Orca desktop app and CLI, ≥ 1.4.245 | `orca --version`; `orca status --json` | Install the Orca app for the platform from [its project](https://github.com/stablyai/orca). Then read `orca skills get orchestration --full` once: it is the full reference for Runs, workers and messages, matched to the installed version |
| Claude Code | `claude --version` | Anthropic's installer, `curl -fsSL https://claude.ai/install.sh \| bash` `(unverified)`, then log in |
| `gh`, logged in, with access to every repository of the config | `gh auth status`; `gh repo view <owner/repo>` per repository | `https://cli.github.com`, then `gh auth login` |
| `git`, `tmux`, `jq` | `git --version; tmux -V; jq --version` | The OS package manager |
| `yq` v4 (mikefarah) | `yq --version` | [`tools/README.md`](../tools/README.md) names the source and the minimum version |
| Engram as Claude's MCP server | `engram version`; `claude mcp list` | [Engram](#engram) below |
| Local clones | `git -C <path> rev-parse --abbrev-ref HEAD` per repository | `git clone` each `remote` into its `path` from the config |
| gentle-ai, optional | `gentle-ai --version` | Not needed. If it is installed, apply [its per-clone setup](./delivery-model.md#when-gentle-ai-is-installed) |

### Orca settings

In the Orca app's settings:

- **Chat UI on.** Ideas and the Tech-lead run as chats, and `orca agent launch` opens a chat only with this on.
- **«Agent sleep» off.** A slept coordinator is not woken by mail ([gotchas](./gotchas.md#agent-sleep-must-stay-off)).
- **«Agent Dashboard» on**, recommended for the human: it shows the agents that need input, such as pending
  permission prompts.

The config records these as `orca.chat_ui`, `orca.agent_sleep` and `orca.agent_dashboard`; nothing sets them for
you.

### Claude Code settings

Model and effort per role come from `models` in the config and are passed at launch. A chat launched with no
`--effort` takes its effort from `~/.claude/settings.json`, and a chat Orca has saved an effort for relaunches with
that one ([gotchas](./gotchas.md#a-chat-relaunches-with-its-saved-effort)). Whether interactive sessions run in auto
mode (`permissions.defaultMode`) is the product owner's choice; no agent changes it.

### Engram

Engram is the shared memory of both chats. Every Engram call passes the project key `memory.engram_project`
explicitly, because Engram otherwise detects the project from the caller's directory, and a worker in another
repository would save elsewhere. Topic keys start with `memory.topic_prefix`.

```bash
go install github.com/Gentleman-Programming/engram/v3/cmd/engram@v3.4.0
claude mcp add -s user engram -- engram mcp --tools=agent
claude mcp list | grep engram      # → engram: ... ✔ Connected
```

The install needs Go. The `claude mcp add` line was built from `claude mcp add --help` `(unverified)` as a command.

**The memory does not travel by itself.** Engram keeps its store on the machine (`~/.engram` unless
`ENGRAM_DATA_DIR` says otherwise). To carry a project to another machine:

```bash
engram export <file> --project <engram project>   # on the old machine
engram import <file>                              # on the new machine
engram projects list                              # → the project, with the same observation count
```

The export holds the memory content: carry it out of band, and never commit it or leave it in a repository, a
worktree or `/tmp`. **Without a transfer, the new machine starts with empty memory**, which is a working state: the
hub repository is the source of truth for rules and decisions, and Engram only adds history. The Tech-lead writes
its first inventory entry when it creates its Run and starts the monitors. Run ids are never read from Engram: each
coordinator keeps its own in its Run id file.

## Building the tree

### The config and the env file

Copy `config/stack.example.yaml` to `config/stack.yaml` and fill it
([README, Configuring the stack](../README.md#configuring-the-stack)). Then run `tools/load-config.sh`: it writes
`~/.local/share/<id>/stack.env`, with `HUB_PATH`, `IDEAS_DIR`, `TECH_LEAD_DIR`, the two Run id file paths,
`NOTIFY_MODE`, the monitor settings and the model and effort per role. The monitors source it
([`tools/README.md`](../tools/README.md)).

### Durable folders

Briefs, messages and reports never live under `/tmp`: a reboot clears it, and a worker whose brief is gone receives
only the bare path as its spec.

```bash
mkdir -p ~/.local/share/<id>-ideas/briefs
mkdir -p ~/.local/share/<id>-tech-lead/{briefs,reports,pr-bodies}
cp agents/templates/after-start-ideas.md ~/.local/share/<id>-ideas/after-start.md
cp agents/templates/after-start-tech-lead.md ~/.local/share/<id>-tech-lead/after-start.md
cp agents/team-conventions.md ~/.local/share/<id>-tech-lead/briefs/team-conventions.md
```

Fill the placeholders in the two copied checklists with this machine's values. Every brief ends with the team
conventions; the Tech-lead appends the mirrored copy to each brief it writes, and re-copies it when the source
changes.

| Path | Owner | Holds |
| --- | --- | --- |
| `~/.local/share/<id>-ideas/briefs/` | Ideas | Specs and messages Ideas sends to the Tech-lead |
| `<role dir>/run-id.txt` | each coordinator | Its own Run id, only the id, on one line. The peer and the monitors read it on every send |
| `<role dir>/after-start.md` | each coordinator | Its filled-in after-start checklist, run on a first start and after every reopen |
| `~/.local/share/<id>-tech-lead/briefs/` | Tech-lead | One brief per worker, the messages it sends to Ideas, and the mirrored team conventions |
| `~/.local/share/<id>-tech-lead/reports/` | Tech-lead | Measurement reports |
| `~/.local/share/<id>-tech-lead/pr-bodies/` | Tech-lead | PR bodies passed to `gh pr create --body-file` |
| `~/.local/share/<id>/` | tools | The env file, and the monitors' state and logs as [`tools/README.md`](../tools/README.md) lays them out |

### Register the repositories

Register every repository of the config in Orca. Workers resolve `--repo name:<name>` only against registered
repositories:

```bash
orca repo add --path <absolute path> --json      # once per repository
orca repo list --json
```

Expected: the list holds every repository path of the config.

### The two hub worktrees

The Ideas worktree is top-level. `--no-parent` matters: run from inside an Orca terminal or chat, `worktree create`
otherwise records the new worktree as a child of the caller's worktree.

```bash
orca worktree create --repo path:<hub> --name Ideas --base-branch <hub main branch> --no-parent --json
orca worktree create --repo path:<hub> --name Tech-lead --parent-worktree path:<Ideas> --base-branch <hub main branch> --json
orca worktree list --repo path:<hub> --json
```

Expected: «Tech-lead» lists «Ideas» as its parent. Both lines are built from `orca worktree create --help`
`(unverified)` as exact lines.

### The two chats and their Runs

Start each coordinator as a chat in its worktree: in the Orca app, a new Claude agent tab on the worktree (it opens
as a chat with Chat UI on), or from the CLI:

```bash
orca agent launch --agent claude --worktree path:<Ideas> --surface chat --model <model> --effort <effort> --prompt "<first prompt>" --json
```

Expected: the result reports a chat (`outcome.kind`), and a chat tab appears in the worktree. The `--prompt` is the
chat's first message, sent in that same tab.

**First-build order.** Ideas starts first and creates its Run. Then the Tech-lead starts, creates its Run, and sends
the first handshake to Ideas' Run, whose Run id file exists by then. Ideas answers it. On a first build the identity
step of each checklist is skipped: there is no prior session.

Each coordinator creates its own Run, **from its own chat**, never from a subagent or another chat, because a Run is
bound to the session that creates it ([gotchas](./gotchas.md#a-run-belongs-to-the-session-that-created-it)):

```bash
orca orchestration run-current --json | jq '.result.run'
orca orchestration run-create --objective "<objective>" --json
orca orchestration run-current --json | jq -r '.result.run.id' > <role dir>/run-id.txt
```

The first line checks for a Run already bound to this chat (`null` when none); create one only when there is none,
or when it is fenced or bound elsewhere. Expected: the Run id file holds only the id, on one line. A chat's shell has
`ORCA_AGENT_SESSION_ID` and no `ORCA_TERMINAL_HANDLE`, so its Run binds no terminal and its coordinator handle shows
`null`; that is expected. The `.result.run` paths are taken from `run-current`'s output `(unverified)` on 1.4.245.

### Workers

The Tech-lead starts one worker per work unit, from its own chat and under its Run, from a brief file in its durable
folder:

```bash
test -s ~/.local/share/<id>-tech-lead/briefs/<brief>.md
orca orchestration worker-start \
  --spec "Your brief is the file <absolute brief path>. Read it whole first and follow it exactly." \
  --task-title "<title>" --worktree new-child --name <worktree name> --repo name:<repo> --base-branch <ref> \
  --agent claude --model <model> --effort <effort> --json
```

- The model and effort come from the seniority the Tech-lead picks: `models.senior`, `models.mid` or
  `models.junior` in the config.
- The brief follows [`agents/templates/brief.md`](../agents/templates/brief.md) and ends with the team conventions.
  Write its path in full in `--spec`.
- `--base-branch` is the feature's integration branch ([delivery model](./delivery-model.md)).
- Expected: JSON with the task and dispatch ids. The workers' mail arrives in the Tech-lead's Run mailbox, the same
  one Ideas writes to.
- To reuse a worktree for a correction or a follow-up after `worker_done`: `--worktree path:<absolute path>` with no
  `--name`, `--repo` or `--base-branch`.
- A worker's scratch lives under Orca's chat scratch folder (`~/.config/orca/chat-scratch/<id>/` on Linux
  `(unverified)` on other platforms). It can hold sensitive exports; delete it after use.

### The monitors

The Tech-lead runs two long-lived scripts in detached tmux sessions, so they survive its own process:

- the **PR monitor** polls `gh` for every repository of the config and sends one `[PR monitor] ...` message per
  poll with every change (new PR, state, review, comments);
- the **permission watch** looks for workers stopped on a permission prompt and sends `[Worker watch] ...`.

In `notify_mode: run` both send to the Tech-lead's Run, reading its id from the Run id file on every send, so a new
Run needs no restart. Install, start, stop and log locations are in [`tools/README.md`](../tools/README.md).
Expected: `tmux ls` lists both sessions, and an alive check arrives in the Tech-lead's mailbox.

## The mailbox protocol

Ideas and the Tech-lead are both chats. Each one:

- is the top-level coordinator of its own Run;
- keeps its Run id in its Run id file, and reads the peer's id from the peer's file on every send, because it
  changes when the peer creates a new Run;
- sends with a subject prefix: `[From Ideas]` (or `[From Ideas, product owner's decision]`) from Ideas,
  `[Tech-lead]` from the Tech-lead.

Nobody types into another agent's terminal or chat
([gotchas](./gotchas.md#typing-into-another-agent-overwrites-the-humans-input)).

### Receiving

An idle chat bound to a Run receives an Orca nudge, a new prompt, when mail arrives
([gotchas](./gotchas.md#orca-nudges-an-idle-chat-when-its-run-gets-mail)). No background wait is kept alive. On a
nudge:

```bash
orca orchestration check --run <own run id> --json
```

The output is the whole Delivery: every unacknowledged message, heartbeats included, and its id in
`.result.deliveryId`. Read every message and act on each, then acknowledge:

```bash
orca orchestration check --run <own run id> --ack <delivery-id> --json
```

Repeat until `deliveryId` is `null`. A Run replays the same Delivery until it is acknowledged, so an unacknowledged
batch hides newer mail. When a step must block until a reply (the bootstrap's round trip, for example), use
`--wait --timeout-ms <n>` with a Bash timeout above `<n>`
([gotchas](./gotchas.md#a-mailbox-wait-outlives-its-bash-timeout)).

### Sending

Write the body to a file first, in the sender's durable folder; long instructions go in a spec file the message
points to. Then:

```bash
orca orchestration send --to "run:$(cat <peer run-id file>)" --type status \
  --subject "[From Ideas] <subject>" --body "$(cat <file>)"
```

Expected: the CLI answers with the message id. The file keeps the shell from expanding the body
([gotchas](./gotchas.md#shell-expansion-inside-messages)).

### Who asks whom

- The Tech-lead never asks the product owner directly. Product questions go to Ideas.
- Ideas brings the product owner one concrete decision at a time: the options, the tradeoffs and a recommendation.
- A technical choice the Tech-lead can take, it takes and reports. A reversible choice is assumed and reported.
- Every message about a PR says where it goes: «→ integration branch» or «→ main branch».

### Workers → Tech-lead

Workers reach the Tech-lead only through its Run, with `worker_done`, `ask`, `escalation` and heartbeats. The
Tech-lead answers a question with `orca orchestration reply --id <msg-id> --body "$(cat <file>)"`, sends a note with
`orca orchestration send --to dispatch:<dispatch-id> ...`, and reads a heartbeat as a sign of life only. After
`worker_done` the dispatch is complete; release its terminal with
`orca orchestration worker-release --dispatch <dispatch-id>`.

## What Ideas does

The rules are in the [Ideas card](../agents/roles/ideas/SKILL.md). In short:

- refines a request into a PRD from [`agents/templates/prd.md`](../agents/templates/prd.md), in the hub, on a branch
  that becomes the feature's integration branch in the hub;
- quotes the product owner verbatim in the PRD's decision log, and asks for the exact business rule whenever a
  number must match an external one;
- researches with its own Claude subagents, read-only; a remote read needs the product owner's explicit
  authorization of the destination, the operation and the credential;
- hands the PRD to the Tech-lead through the Tech-lead's Run, and never executes product work itself;
- after a reopen, wakes the Tech-lead with a message that carries a token the Tech-lead echoes back
  ([reboot](./reboot.md));
- saves decisions, and its own mistakes, to Engram.

## What the Tech-lead keeps doing

The rules are in the [Tech-lead card](../agents/roles/tech-lead/SKILL.md) and
[`agents/README.md`](../agents/README.md). The behaviours that must persist:

- **Monitors.** On a merge, a review or a comment, the Tech-lead acts on its own: fixes review comments in a unit PR,
  replies to every comment, removes merged worktrees, and reports to Ideas. Each pending permission prompt is
  reported to Ideas at once, with the exact command and its read on whether it is safe.
- **Inventory** in Engram: its standing Run (id and objective), and every worktree, worker, tmux session, container,
  database and data path it opens, with where it lives, why, and when it is removed. Updated on every open and every
  removal; each worktree is removed when its PR merges.
- **Measure before deciding** when a decision depends on numbers. A setting a measurement depends on is read, not
  assumed.
- **Merge rule.** The Tech-lead merges work units into integration branches once their checks pass; only the
  product owner merges into a main branch ([delivery model](./delivery-model.md)).
- **Integration PRs** are opened ready for review, not draft, and state the deploy order.
- **Lessons** are narrow, for the exact case and how to detect it, never general restrictions.

## A feature end to end

1. **PRD.** Ideas writes it in the hub and hands it over.
2. **Contract**, for a wide feature: a reader worker writes the contract with file ownership, and a UX reader
   writes a note when a screen changes. Before this, the Tech-lead fetches every target repository and cuts the
   integration branches from the fresh main branch ([delivery model](./delivery-model.md#no-work-starts-on-a-stale-base)).
3. **Work units, test-first**, one worker and one worktree each, each a PR into its repository's integration branch.
   In parallel only under the conditions of the [delivery model](./delivery-model.md#the-team-and-its-lanes).
4. **Independent reviewer** ([card](../agents/roles/reviewer/SKILL.md)): per unit for every high-risk unit, with
   one correction round and a recheck of those blockers only. Corrections go in the unit's existing worktree. When
   no unit was high risk, one reviewer checks the integration branch before the integration PRs open.
5. **QA on the real local path** ([card](../agents/roles/qa/SKILL.md)): the integration heads running locally. The
   human logs in where a login is needed.
6. **Close.** The test plan for the product owner from
   [`agents/templates/test-plan.md`](../agents/templates/test-plan.md), and the backlog updated in the hub.
7. **Integration PRs**, one per repository, ready for review and stating the deploy order. The product owner tests,
   merges and decides the deploy; the Tech-lead then removes the feature's worktrees.

### Local test stacks

- The recipe lives outside every repository, in a durable folder next to the data it seeds, with a README listing
  each file, the start and stop commands and the ports.
- Data comes from a read-only export of only the rows the test needs, loaded into a **local** database. A local
  backend built from an unmerged branch never points at a shared database: it may run migrations on start.
- The run scripts refuse any database or storage that is not local; remote storage is replaced by a local emulator
  when the test writes.
- Each service runs in its own tmux session.
- Exports and seeds are real data: never committed, recorded in the inventory, kept or deleted by the product
  owner's decision.

## After a reboot

Follow [`docs/reboot.md`](./reboot.md).
