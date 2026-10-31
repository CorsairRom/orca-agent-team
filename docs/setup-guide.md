# Setup guide

How the agent team is built on a machine, with the reasons behind each step: the Ideas chat, the Tech-lead chat and
its workers, the monitors, the memory, and how a feature runs from a request to the integration PRs.
[`BOOTSTRAP_PROMPT.md`](../BOOTSTRAP_PROMPT.md) executes the same build as checkable steps, from the Orca chat the
human asks to install the team; this guide is the reference it relies on.

The rules themselves live in the documents below, and those win where they say more:

| Document | Holds |
| --- | --- |
| [`agents/README.md`](../agents/README.md) | The operating manual: lifecycle, roles, delivery, quick path |
| [`agents/team-conventions.md`](../agents/team-conventions.md) | Rules for everything an agent writes |
| [`agents/roles/`](../agents/roles/) | One card per role: [Ideas](../agents/roles/ideas/SKILL.md), the [Tech-lead](../agents/roles/tech-lead/SKILL.md), the [reviewer](../agents/roles/reviewer/SKILL.md), [QA](../agents/roles/qa/SKILL.md) and one developer card per repository kind |
| [`agents/templates/`](../agents/templates/) | PRD, brief, worker report, test plan, and the after-start checklists of [Ideas](../agents/templates/after-start-ideas.md) and the [Tech-lead](../agents/templates/after-start-tech-lead.md) |
| [`tools/README.md`](../tools/README.md) | The env file, the PR monitor and the permission watch |
| [`docs/delivery-model.md`](./delivery-model.md) | The default workflow: integration branches, work-unit PRs, who merges |
| [`docs/gotchas.md`](./gotchas.md) | Known gotchas |
| [`docs/providers.md`](./providers.md) | Optional workers on other agents, such as Antigravity or OpenCode v2 |
| [`docs/reboot.md`](./reboot.md) | Reboot and reopen |

Ideas and the Tech-lead are Claude Code sessions in Orca chats (Chat UI on), each the top-level coordinator of its
own Run, and they talk only through those Runs' mailboxes. The `orca` commands match `--help` on the minimum Orca
version in the [README](../README.md#prerequisites); anything the help does not confirm is marked `(unverified)`.

## Placeholders

Every `<...>` in this guide, its meaning, who fills it and when, is in the
[placeholder table](../agents/README.md#placeholders).

## What you are building

```
product owner ── talks only to Ideas
 └─ Ideas · Claude Code in an Orca chat, hub worktree "Ideas"
      ├─ its own Run: a mailbox, id in <ideas dir>/run-id.txt
      ├─ its own Claude subagents: read-only research
      └─ Run-to-Run mail (orca orchestration send --to run:<peer run id>), never a worker relation
          └─ Tech-lead · Claude Code in an Orca chat, hub worktree "Tech-lead", a child worktree of "Ideas"
               ├─ its own standing Run, reused across features, id in <tech-lead dir>/run-id.txt:
               │    workers started with worker-start --worktree new-child, one worktree per work unit
               ├─ tmux: PR monitor        → PR changes to the Tech-lead's Run mailbox
               └─ tmux: permission watch  → pending permission prompts to the Tech-lead's Run mailbox
Shared memory: Engram, project memory.engram_project, read and written by every chat
```

**Why two coordinators.** The Tech-lead cannot be a dispatched worker of Ideas: Orca's nesting depth is 1, and a
worker that starts its own worker is refused ([gotchas](./gotchas.md#nesting-depth-is-1)). So both are top-level
coordinators with their own Runs, and they talk Run to Run.

**Why a separate installing chat.** A Run is bound to the session that created it
([gotchas](./gotchas.md#a-run-is-bound-to-the-session-that-created-it)). The chat that installs the team launches
Ideas and the Tech-lead as fresh chats, and each creates its own Run in its first turn. The installing chat is
neither of them.

## Prerequisites

The tools and their minimum versions are in the [README](../README.md#prerequisites). How to get the ones that need
more than a package manager:

| Need | Check | If missing |
| --- | --- | --- |
| Orca desktop app and CLI | `orca --version`; `orca status --json` | Install the Orca app for the platform from [its project](https://github.com/stablyai/orca). Then read `orca skills get orchestration --full` once: it is the full reference for Runs, workers and messages, matched to the installed version |
| Claude Code | `claude --version` | Anthropic's installer, `curl -fsSL https://claude.ai/install.sh \| bash` `(unverified)`, then log in |
| `gh`, logged in, with access to every repository of the config | `gh auth status`; `gh repo view <owner/repo>` per repository | `https://cli.github.com`, then `gh auth login` |
| `git`, `tmux`, `jq` | `git --version; tmux -V; jq --version` | The OS package manager |
| Engram as Claude's MCP server | `engram version`; `claude mcp list` | [Engram](#engram) below |
| Local clones | `git -C <path> rev-parse --abbrev-ref HEAD` per repository | `git clone` each `remote` into its `path` from the config |

### Orca settings

The three settings the human sets in the Orca app; nothing sets them for you. The config records them as
`orca.chat_ui`, `orca.agent_sleep` and `orca.agent_dashboard`.

- **Chat UI on.** Ideas and the Tech-lead run as chats, and `orca agent launch --surface chat` opens a chat only
  with this on.
- **"Agent sleep" off.** Ideas and the Tech-lead wait idle for mail, and mail does not wake a slept agent
  `(unverified)` ([gotchas](./gotchas.md#agent-sleep-must-stay-off)).
- **"Agent Dashboard" on**, for the human: it shows the agents that need input, such as pending permission prompts.

### Claude Code settings

Model and effort per role come from `models` in the config and are passed at launch. A chat launched with no
`--effort` takes its effort from `~/.claude/settings.json`, and a chat Orca has saved an effort for relaunches with
that one ([gotchas](./gotchas.md#a-chat-relaunches-with-its-saved-effort)). Whether interactive sessions run in auto
mode (`permissions.defaultMode`) is the product owner's choice; no agent changes it.

### If your agents load global instructions or plugins

The team needs no tool beyond the prerequisites. When the agents on the machine load global instructions or
plugins of their own:

- **The brief wins.** Inside an Orca dispatch, the worker's brief takes precedence over any global instruction or
  plugin: questions go through `orca orchestration ask`, the base branch is the one the brief names, and the team's
  memory process applies.
- **Keep tool state out of commits.** Files a tool writes into a clone for its own bookkeeping never go into a
  commit.
- **List such folders in `.git/info/exclude`.** The file is local to the clone and outside the repository's history:

```bash
printf '%s\n' '<tool folder>/' >> <repo path>/.git/info/exclude
```

### Engram

Engram is the shared memory of both chats. Every Engram call passes the project key `memory.engram_project`
explicitly, because Engram otherwise detects the project from the caller's directory, and a worker in another
repository would save elsewhere. Engram refuses an explicit project it holds no observation of, so the installing
chat creates it once ([memory](../agents/README.md#memory)). Topic keys start with `memory.topic_prefix`; the topics the cards name are
defaults, and a team may lay them out differently.

Install Engram as [its own README](https://github.com/Gentleman-Programming/engram#readme) says, then register it
as Claude Code's MCP server and check it:

```bash
claude mcp add -s user engram -- engram mcp --tools=agent
claude mcp list | grep engram      # → engram: ... ✔ Connected
```

The `claude mcp add` line follows `claude mcp add --help`; its exact form is `(unverified)`.

**The memory does not travel by itself.** Engram keeps its store on the machine (`~/.engram` unless
`ENGRAM_DATA_DIR` says otherwise). To carry a project to another machine:

```bash
engram export <file> --project <engram project>   # on the old machine
engram import <file>                              # on the new machine
engram projects list                              # → the project, with the same observation count
```

The export holds the memory content: carry it out of band, and never commit it or leave it in a repository, a
worktree or `/tmp`. **Without a transfer, the new machine starts with empty memory**, which is a working state: the
hub repository is the source of truth for rules and decisions, and Engram only adds history. Run ids are never read
from Engram: each coordinator keeps its own in its run-id file.

### Credentials

Every worker inherits the environment Orca was started with, and an agent that runs `env` sends what it prints to
its model provider ([gotchas](./gotchas.md#every-worker-inherits-orcas-environment)). So no credential lives in the
global environment:

- **No global exports.** A shell profile does not export a `GITHUB_TOKEN`, a `<PROVIDER>_API_KEY` or any other
  secret.
- **Each tool's own auth store.** `gh auth login`, Claude Code's login and each agent's own sign-in keep their
  credentials where only that tool reads them.
- **A file the config references.** A config that needs a key points to a file instead of holding the value, such
  as OpenCode's `{file:~/.secrets/<provider>-key}`. The file is `chmod 600`, outside every repository.
- **A secret store**, such as the OS keychain, for anything a tool reads at run time.

## Building the tree

### The config and the env file

`config/stack.yaml` describes the stack ([README, Configuring the stack](../README.md#configuring-the-stack)). When
it is missing, the installing chat builds it with the human from
[`config/stack.example.yaml`](../config/stack.example.yaml), one question at a time. Then it reads the config
itself, with no YAML parser, validates it and writes `<team dir>/stack.env`, with every value a
bash step needs: the hub path and main branch, every repository, the two run-id file paths, the durable folders,
the monitor settings and the model and effort per role
([Writing the env file](../tools/README.md#writing-the-env-file)). The monitors, the bootstrap and both
after-start checklists source it; no bash step reads the YAML.

### Durable folders

Briefs, messages and reports never live under `/tmp`: a reboot clears it, and a worker whose brief is gone receives
only the bare path as its spec. Everything local to the team lives in one tree, with the env-file key of each
folder. The default team's tree is the stack's own; a named team's is `teams/<team id>/` inside it, with the same
layout ([several teams](#several-teams-on-one-stack)):

```
~/.local/share/<stack.id>/    STACK_DIR
├── stack.env                 STACK_ENV_FILE
├── ideas/                    IDEAS_DIR: run-id.txt, resume-prompt.txt, briefs/
├── tech-lead/                TECH_LEAD_DIR: run-id.txt, resume-prompt.txt, handshake-ok.txt, conventions.txt,
│                             briefs/, reports/, pr-bodies/
├── monitors/                 MONITOR_DIR: state and logs of both monitors
├── bootstrap/                BOOTSTRAP_DIR: the installing chat's files
└── teams/<team id>/          TEAM_DIR of a named team: its own stack.env, ideas/, tech-lead/, monitors/, bootstrap/
```

The installing chat creates the folders in
[bootstrap step 5](../BOOTSTRAP_PROMPT.md#step-5-create-the-durable-folders-the-engram-project-and-the-two-hub-worktrees);
the monitors create `monitors/` themselves.

| Path | Owner | Holds |
| --- | --- | --- |
| `<ideas dir>/briefs/` | Ideas | Specs and messages Ideas sends to the Tech-lead |
| `<ideas dir>/run-id.txt`, `<tech-lead dir>/run-id.txt` | each coordinator | Its own Run id, only the id, on one line. The peer and the monitors read it on every send |
| `<ideas dir>/resume-prompt.txt`, `<tech-lead dir>/resume-prompt.txt` | the installing chat | The prompt the human pastes to resume a chat ([reboot](./reboot.md)) |
| `<tech-lead dir>/handshake-ok.txt` | Tech-lead | Ideas' Run id, written when Ideas answers the first handshake |
| `<tech-lead dir>/briefs/` | Tech-lead | One brief per worker and the messages it sends to Ideas |
| `<tech-lead dir>/reports/` | Tech-lead | Reports it keeps |
| `<tech-lead dir>/pr-bodies/` | Tech-lead | PR bodies passed to `gh pr create --body-file` |
| `<tech-lead dir>/branches.txt` | Tech-lead | The team's integration branches, when the PR monitor filters by team ([teams](../tools/README.md#teams)) |
| `<team dir>/stack.env`, `<tech-lead dir>/conventions.txt` | the chat that writes the env file | The env file and the conventions file ([Writing the env file](../tools/README.md#writing-the-env-file)) |
| `<team dir>/monitors/` | the monitors | Their state and logs ([`tools/README.md`](../tools/README.md#logs-and-state)) |
| `<team dir>/bootstrap/` | the installing chat | Its prompts and the worktree paths; it holds no secret |

### Register the repositories

Register every repository of the config in Orca. Workers resolve `--repo path:<repo path>` only against registered
repositories:

```bash
orca repo add --path <absolute path> --json      # once per repository
orca repo list --json
```

Expected: the list holds every repository path of the config.

### The two hub worktrees

The Ideas worktree is top-level. `--no-parent` matters: run from inside an Orca chat, `worktree create` otherwise
uses the parent it infers from the current context (`orca worktree create --help`).

```bash
orca worktree create --repo path:<hub path> --name <ideas worktree name> --base-branch <hub main branch> --no-parent --json
orca worktree create --repo path:<hub path> --name <tech-lead worktree name> --parent-worktree path:<ideas worktree> --base-branch <hub main branch> --json
orca worktree list --repo path:<hub path> --json
```

Expected: the Tech-lead's worktree lists the Ideas worktree as its parent. The default team's are named "Ideas"
and "Tech-lead"; a named team's carry its id, such as "Ideas-billing". Orca chooses where a worktree lives, which need not be next to
the hub clone: read each absolute path from the `--json` output instead of assuming it.

### The two chats and their Runs

The installing chat launches each coordinator as a fresh chat in its worktree. The `--prompt` is the chat's first
message; it names the role card and the after-start checklist to run as a FIRST START:

```bash
orca agent launch --agent claude --surface chat --worktree path:<ideas worktree> --model <model> --effort <effort> --prompt "$(cat <first prompt file>)" --json
```

Expected: the result reports a chat (`outcome.kind`), and a chat tab appears in the worktree. `--surface chat` is
refused when Orca can tell that the agent cannot open as a chat there; when support cannot be checked, the launch
may fall back to a terminal, and `receipt.detail` says so (`orca agent launch --help`).

**First-start order.** Ideas starts first: it creates its Run, writes its run-id file, and ends its turn waiting
for the handshake. Then the Tech-lead starts, creates its Run, writes its run-id file, and sends `[Tech-lead] ready`
to Ideas' Run. Ideas answers `[From Ideas] handshake received`, and the Tech-lead records the confirmation in
`<tech-lead dir>/handshake-ok.txt`, which the installing chat reads. On a first start the identity step of each
checklist is skipped: there is no prior session.

Each coordinator creates its own Run **from its own chat**, never from a subagent or another chat:

```bash
orca orchestration run-current --json | jq '.result.run'
orca orchestration run-create --objective "<objective>" --json
orca orchestration run-current --json | jq -r '.result.run.id' > <ideas dir>/run-id.txt   # or <tech-lead dir>/run-id.txt
```

The first line checks for a Run already bound to this chat (`null` when none); the chat creates one only when there
is none or the old one is unusable. Expected: the run-id file holds only the id, on one line. The `.result.run.id`
path is `(unverified)`.

### Workers

The Tech-lead starts one worker per work unit, from its own chat and under its Run, from a brief file in its durable
folder:

```bash
test -s <tech-lead dir>/briefs/<brief>.md
orca orchestration worker-start \
  --spec "Your brief is the file <absolute brief path>. Read it whole first and follow it exactly." \
  --task-title "<title>" --worktree new-child --name <worktree name> --repo path:<repo path> --base-branch <ref> \
  --agent claude --model <model> --effort <effort> --json
```

- The model and effort come from the seniority the Tech-lead picks: `models.senior`, `models.mid` or
  `models.junior` in the config.
- The brief follows [`agents/templates/brief.md`](../agents/templates/brief.md): it carries the team's
  `conventions:` and ends with the team conventions. Write its path in full in `--spec`.
- `--base-branch` is the brief's `<target branch>`, from the [delivery model](./delivery-model.md): by default the
  feature's integration branch.
- Expected: JSON with the task and dispatch ids. The workers' mail arrives in the Tech-lead's Run mailbox, the same
  one Ideas writes to.
- To reuse a worktree for a correction or a follow-up after `worker_done`: `--worktree path:<absolute path>` with no
  `--name`, `--repo` or `--base-branch`.
- A worker keeps its scratch files outside every repository, and deletes them after use.

### Other providers (optional)

Every worker is Claude unless the config's optional `providers:` section lists another agent, such as Antigravity
or OpenCode v2, for some task kinds. Each one needs its own setup, HUMAN steps included, and a passed smoke test
before its first unit: [providers](./providers.md). Skip this step for a Claude-only team.

### The monitors

The Tech-lead's two long-lived scripts run in detached tmux sessions, so they survive its process:

- the **PR monitor** polls `gh` for every repository of the config and sends one `[PR monitor] ...` message per
  poll with every change (new PR, state, review, comments);
- the **permission watch** reads Orca's observation of each worker, looks for workers parked on a prompt only a
  human can answer, and sends `[Worker watch] ...`, also for a worker it cannot observe.

Both send to the Tech-lead's Run, reading its id from the run-id file on every send, so a new Run needs no restart.
The Tech-lead starts them from its own chat, on its first start and on every resume, so they send under its Orca
identity ([gotchas](./gotchas.md#a-tmux-session-sends-under-the-identity-it-was-started-with)); the installing chat
only checks them. Install, start, stop and log
locations are in [`tools/README.md`](../tools/README.md). Expected: `tmux ls` lists `<tmux prefix>-pr-monitor` and
`<tmux prefix>-worker-watch`, and an alive check arrives in the Tech-lead's mailbox.

### Several teams on one stack

Each team is a pair of chats, Ideas and a Tech-lead, with its own Runs, monitors, durable folders and backlog, so two
large features that differ do not share one product-owner queue or one Tech-lead context. A team is installed with
the [bootstrap](../BOOTSTRAP_PROMPT.md#step-2-the-config), which asks for its `<team id>`; the first team is the
default one, with an empty id.

| Per team | Shared by every team of the stack |
| --- | --- |
| `TEAM_DIR` and everything in it: env file, run-id files, briefs, reports, monitor state | `config/stack.yaml`, models, conventions, languages |
| The two hub worktrees, `Ideas-<team id>` and `Tech-lead-<team id>` | The hub repository, its PRD and decision folders |
| The Runs, the workers and their worktrees | The repositories of the stack and their clones |
| The monitor sessions `<stack.id>-<team id>-*` and the PR branches file | The `gh` account the PR monitor polls with |
| The backlog file, `BACKLOG-<team id>.md` by default, and the inventory topic | The Engram project and every role lesson |

- **Two teams never work on the same feature.** A feature belongs to the team whose Ideas wrote its PRD. When two
  features touch the same repository, each team's Tech-lead works on its own integration branch; a change one team
  needs from the other goes to the product owner, who carries it between the two Ideas chats.
- **Local resources are not split.** Worktrees isolate files, not ports, databases or containers. Each Tech-lead
  records what it starts in its inventory; before starting a service, check that the port is free.
- **The PR monitor filters by branch.** Every team's monitor polls the same `gh` account, so a team that is not
  alone keeps its branches file ([teams](../tools/README.md#teams)).

## The mailbox protocol

Ideas and the Tech-lead are both chats. Each one:

- is the top-level coordinator of its own Run;
- keeps its Run id in its run-id file, and reads the peer's id from the peer's file on every send, because it
  changes when the peer creates a new Run;
- sends with a subject prefix: `[From Ideas]` (or `[From Ideas, product owner's decision]`) from Ideas,
  `[Tech-lead]` from the Tech-lead.

Nobody types into another agent's chat or terminal
([gotchas](./gotchas.md#typing-into-another-agent-overwrites-the-humans-input)).

### Receiving

Each chat receives its mail by [the mailbox rule](../agents/README.md#the-mailbox-rule).

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
- Every message about a PR says where it goes, in the wording of the
  [template defaults](../agents/README.md#template-defaults).

### Workers → Tech-lead

Workers reach the Tech-lead only through its Run, with `worker_done`, `ask`, `escalation` and heartbeats. The
Tech-lead answers a question with `orca orchestration reply --id <msg-id> --body "$(cat <file>)"`, sends a note with
`orca orchestration send --to dispatch:<dispatch-id> ...`, and reads a heartbeat as a sign of life only. After
`worker_done` the dispatch is complete; release its terminal with
`orca orchestration worker-release --dispatch <dispatch-id>`.

## What Ideas does

The rules are in the [Ideas card](../agents/roles/ideas/SKILL.md). In short:

- refines a request into a PRD from [`agents/templates/prd.md`](../agents/templates/prd.md), in the hub, where
  `hub.prds_dir` says;
- quotes the product owner verbatim in the PRD's decision log;
- researches with its own Claude subagents, read-only;
- hands the PRD to the Tech-lead through the Tech-lead's Run, and never executes product work itself;
- on a resume, wakes the Tech-lead with a message that carries a token the Tech-lead echoes back
  ([reboot](./reboot.md));
- saves the product owner's decisions to Engram.

## What the Tech-lead keeps doing

The rules are in the [Tech-lead card](../agents/roles/tech-lead/SKILL.md) and
[`agents/README.md`](../agents/README.md). The behaviours that persist:

- **Monitors.** On a merge, a review or a comment, the Tech-lead acts on its own: fixes review comments in a unit PR,
  replies to every comment, removes merged worktrees, and reports to Ideas. Each pending permission prompt is
  reported to Ideas at once, with the exact command and its read on whether it is safe.
- **Inventory** in Engram (by default the topic `<inventory topic>`): its standing Run (id and
  objective), and every worktree, worker, tmux session and path it opens, with where it lives, why, and when it is
  removed. Each worktree is removed when its PR merges.
- **Conventions.** Every brief carries the config's `conventions:` list; a new project starts with none.
- **Merges** follow the [delivery model](./delivery-model.md): by default the Tech-lead merges work units into
  integration branches once their checks pass, and only the product owner merges into a main branch.

## A feature end to end

The default workflow; the [delivery model](./delivery-model.md) explains it and the `delivery:` keys that change it.

1. **PRD.** Ideas writes it in the hub and hands it over.
2. **Contract**, for a wide feature: a reader worker writes the contract with file ownership. Before this, the
   Tech-lead fetches every target repository and cuts the integration branches from the fresh main branch
   ([delivery model](./delivery-model.md#no-work-starts-on-a-stale-base)).
3. **Work units**, one worker and one worktree each, each a PR into its repository's integration branch. In
   parallel only under the conditions of the [delivery model](./delivery-model.md#the-team-and-its-lanes).
4. **Independent reviewer** ([card](../agents/roles/reviewer/SKILL.md)): per unit for every high-risk unit, with
   the correction rounds of the [template defaults](../agents/README.md#template-defaults) and a recheck of those
   blockers only. When no unit was high risk, one reviewer checks the integration branch before the integration
   PRs open.
5. **QA** ([card](../agents/roles/qa/SKILL.md)) when a screen or an API changed.
6. **Close.** The test plan for the product owner from
   [`agents/templates/test-plan.md`](../agents/templates/test-plan.md), and the backlog (`hub.backlog_file`)
   updated in the hub.
7. **Integration PRs**, one per repository. The product owner tests and merges; the Tech-lead then removes the
   feature's worktrees.

## After a reboot

Follow [`docs/reboot.md`](./reboot.md).

## Uninstall

With the example stack `acme`. Steps marked **HUMAN** need the human in the Orca UI.

1. Kill the tmux sessions `acme-pr-monitor` and `acme-worker-watch` ([stop and restart](../tools/README.md#stop-and-restart)).
2. Close the chats: Ideas, the Tech-lead and any worker chat.
3. Remove the Ideas, Tech-lead and worker worktrees with `orca worktree rm --force`, taking each path from
   `orca worktree list`. It also deletes a branch it can prove is merged ([gotchas](./gotchas.md#orca-worktree-rm-also-deletes-the-branch)).
4. Remove `~/.local/share/acme/`.
5. Optionally, only to drop the memory: `engram delete project <memory.engram_project> --hard`. Small 0-observation
   projects named after worktrees may also exist ([gotchas](./gotchas.md#engram-may-create-small-projects-named-after-worktrees)).
6. **HUMAN:** remove each repository from Orca's sidebar, because the minimum Orca version has no CLI command for it.
7. Runs cannot be deleted; the old ones stay in `orca orchestration run-list`.

To remove one named team only, follow steps 1 to 4 with that team's sessions (`acme-<team id>-pr-monitor` and
`acme-<team id>-worker-watch`), chats and worktrees, and remove `~/.local/share/acme/teams/<team id>/` instead of the
whole tree. The other teams, the config, the memory and the repositories stay.
