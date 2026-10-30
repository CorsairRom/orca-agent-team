# Operating manual

How a request travels from the product owner to merged code through a team of agents coordinated on Orca. This
folder is the manual every agent of the team reads: the roles, the lanes, seniority, how the two permanent chats
talk, how workers are dispatched, and the rules for review, QA, memory and cleanup.

| Read | For |
| --- | --- |
| [`team-conventions.md`](./team-conventions.md) | The rules for everything an agent writes: code, PRs, commits, copy, git, commands |
| [`roles/`](./roles/) | One card per role: [Ideas](./roles/ideas/SKILL.md), [tech lead](./roles/tech-lead/SKILL.md), [reviewer](./roles/reviewer/SKILL.md), [QA](./roles/qa/SKILL.md), and one developer card per repository kind |
| [`templates/`](./templates/) | [PRD](./templates/prd.md), [brief](./templates/brief.md), [worker report](./templates/worker-report.md), [test plan](./templates/test-plan.md), and the after-start checklists of [Ideas](./templates/after-start-ideas.md) and the [tech lead](./templates/after-start-tech-lead.md) |
| [`../docs/delivery-model.md`](../docs/delivery-model.md) | One integration branch per feature, work-unit PRs, who merges |
| [`../docs/setup-guide.md`](../docs/setup-guide.md) | Building the whole setup on a machine |
| [`../docs/reboot.md`](../docs/reboot.md) | What to do after a reboot or a chat reopen |
| [`../docs/gotchas.md`](../docs/gotchas.md) | Known Orca and Claude Code behaviours that break the workflow if ignored |
| [`../tools/README.md`](../tools/README.md) | The PR monitor and the worker permission watch |
| [`../config/stack.example.yaml`](../config/stack.example.yaml) | The stack's configuration: repositories, memory, languages, models, Orca settings |

## Placeholders

The cards and templates are stack-agnostic. Wherever they show one of these, use the value from the stack's
`config/stack.yaml`, or from the env file `tools/load-config.sh` writes from it.

| Placeholder | Meaning | Env file key |
| --- | --- | --- |
| `<id>` | `stack.id`, such as `acme` | `STACK_ID` |
| `<stack.name>` | `stack.name`, the display name, such as `ACME platform` | `STACK_NAME` |
| `<hub>` | The repository of kind `hub`: Ideas and the tech lead live in its worktrees; PRDs, decisions and the backlog are kept there | `HUB_PATH`, `HUB_REMOTE` |
| `<team repo>` | The local clone of this repository | none |
| `<ideas dir>` | `~/.local/share/<id>-ideas`: Ideas' durable folder | `IDEAS_DIR` |
| `<tech-lead dir>` | `~/.local/share/<id>-tech-lead`: the tech lead's durable folder | `TECH_LEAD_DIR` |
| `<ideas run-id file>` | `<ideas dir>/run-id.txt`: Ideas' Run id, only the id, on one line | `IDEAS_RUN_ID_FILE` |
| `<tech-lead run-id file>` | `<tech-lead dir>/run-id.txt`: the tech lead's Run id | `TECH_LEAD_RUN_ID_FILE` |
| `<engram project>` | `memory.engram_project`: the Engram project key every chat and worker uses | `ENGRAM_PROJECT` |
| `<prefix>` | `memory.topic_prefix`: topic keys are `<prefix>/<domain>/<topic>` | `TOPIC_PREFIX` |
| `<main-line>` | A repository's `main_branch` in `repos[]`, such as `main` or `develop` | none |
| `<model>`, `<effort>` | A role's or a seniority level's `models.<key>.model` and `.effort` | `MODEL_<KEY>`, `EFFORT_<KEY>` |

## The team

```
Product owner ── talks only to Ideas
 └─ Ideas · Claude Code in an Orca chat, in a hub worktree
      ├─ its own Run: an inbox, id in <ideas run-id file>
      ├─ its own Claude subagents: read-only research
      └─ Run-to-Run mail, never a worker relation
          └─ Tech lead · Claude Code in an Orca chat, in a hub worktree nested under Ideas'
               ├─ its own standing Run, reused across features, id in <tech-lead run-id file>
               │    └─ workers: one Orca worker and one worktree per work unit (worker-start --worktree new-child)
               ├─ PR monitor    → PR changes to the tech lead's Run mailbox
               └─ worker watch  → pending permission prompts to the tech lead's Run mailbox
Shared memory: Engram, project <engram project>, read by every agent, written by Ideas and the tech lead
```

The tech lead is not a worker of Ideas: Orca's nesting depth is 1, so a worker cannot start its own workers. Both
are top-level coordinators, each with its own Run, and they talk Run to Run.

## Quick path

1. **The product owner refines a request in the Ideas chat**, which writes a PRD from
   [`templates/prd.md`](./templates/prd.md) into the hub, or a reasoned discard.
2. **The tech lead triages it**: type, repositories, lane and seniority. It rejects work outside the stack's
   repositories (`repos[]`), with the reason.
3. **The tech lead plans the feature in Orca**: in its standing Run, one task per work unit, a contract task first
   when repositories depend on each other, and one brief per task from [`templates/brief.md`](./templates/brief.md).
4. **Workers deliver** with `worker_done` and a report from [`templates/worker-report.md`](./templates/worker-report.md),
   including every assumption they made.
5. **The reviewer, then QA when warranted**: an independent reviewer for every high-risk unit, or, when no unit was
   high risk, one reviewer on the integration branch before the integration PRs.
6. **The tech lead hands the product owner a test plan** from [`templates/test-plan.md`](./templates/test-plan.md),
   through Ideas. The product owner tests and merges into each repository's main branch.

## Mandatory before any work

No work starts on a stale base.

- **Feature start:** the tech lead runs `git fetch origin` on each target repository and cuts (or updates) the
  feature's integration branch from the fresh `origin/<main-line>`.
- **Worker start:** every worker runs `git fetch origin` and checks its base holds the latest main line:
  `git merge-base --is-ancestor origin/<main-line> HEAD`. If it does not, it does not start: it asks the tech lead
  with `orca orchestration ask`. The tech lead brings the integration branch up to date; workers never rebase or
  update it themselves.
- The check and its result appear in the worker report under Verification.

## Roles

Each role is a card under [`roles/`](./roles/) plus its Engram topic `<prefix>/roles/<role>/*`. A developer card
exists per repository kind (`repos[].kind`); a repository of kind `other` uses the closest card, and the brief
names the differences.

| Role | Card | Writes | Runs as | Seniority |
| --- | --- | --- | --- | --- |
| Ideas | [ideas](./roles/ideas/SKILL.md) | PRDs in the hub, never code | Permanent chat | `models.ideas` |
| Tech lead | [tech-lead](./roles/tech-lead/SKILL.md) | Briefs, test plans, hub notes, never product code | Permanent chat | `models.tech_lead` |
| Frontend developer | [dev-frontend](./roles/dev-frontend/SKILL.md) | Repositories of kind `frontend` | Orca worker | Per task |
| Backend developer | [dev-backend](./roles/dev-backend/SKILL.md) | Repositories of kind `backend` | Orca worker | Per task |
| Docs developer | [dev-docs](./roles/dev-docs/SKILL.md) | Repositories of kind `docs` | Orca worker | Mid or junior |
| Infrastructure developer | [dev-infra](./roles/dev-infra/SKILL.md) | Repositories of kind `infra`, and CI, containers or deployment in any repository | Orca worker | Senior, always |
| Reviewer | [reviewer](./roles/reviewer/SKILL.md) | A verdict | Orca worker | Senior |
| QA | [qa](./roles/qa/SKILL.md) | A QA report | Orca worker | Mid |

**Notes before code.** Two kinds of note are written by workers dispatched with a brief, not by a dedicated
card, and they never block a developer:

- **Contract** (wide feature, senior, in the hub): API endpoints and schemas with examples, file ownership per task,
  the shared registries (routes, migrations, dependencies, flags) each task may touch and who owns each, and the
  order in which interface changes land. It is also the only route for anything new that crosses domains: it says
  whether the existing infrastructure covers it, or states it as a decision for the tech lead.
- **Screen note** (any task that changes a screen, mid, read-only): the existing components and patterns to reuse,
  with paths and the reference screen; the vocabulary and copy for every new label, in `language.app_copy`; the
  states to cover (empty, loading, error, no permission); what not to invent. At most one page, sent to the
  frontend developer with `orca orchestration send` and in the report.

## Lanes

| Lane | When | Who takes part |
| --- | --- | --- |
| Small | A question, or a fix contained in one place | One developer · reviewer |
| Bounded feature | One repository | Brief · one developer · screen note if a screen changes · reviewer · QA if a screen changes |
| Wide feature | Several repositories, or a large change | PRD · contract task first · developers in parallel only under the conditions below · screen notes · reviewer per high-risk unit, else on the integrated result · QA |

**Parallel developers** need all of these, or they work in series:

- the tech lead wrote a contract with file ownership before splitting the work;
- the units share no files and no shared registries (routes, migrations, dependencies, flags);
- each finished interface change is announced to the other running developers;
- the merged result is verified by the reviewer;
- a coupled change is written by a single provider.

## Seniority

Seniority is agent + model + effort, chosen per task by the tech lead. The values come from `models` in the
config; these are what each level is for. Before adding a second writer, raise the effort of one.

| Level | Config key | For |
| --- | --- | --- |
| Senior | `models.senior` | Contract tasks, coupled or cross-repository changes, infrastructure, review |
| Mid | `models.mid` | A bounded feature in one repository, screen notes, QA |
| Junior | `models.junior` | Mechanical work: docs, renames, a test of a known shape |

Ideas and the tech lead use `models.ideas` and `models.tech_lead`. Another provider (such as `codex` or
`opencode`) joins the table only after a smoke test proves its worker reads its role card and reaches Engram with
`<engram project>`.

## The Run mailboxes

Ideas and the tech lead are both Orca chats, each the top-level coordinator of its own Run, with its id in its own
run-id file. They talk only through those Runs. The steps that set this up are the two after-start checklists:
[Ideas'](./templates/after-start-ideas.md) and the [tech lead's](./templates/after-start-tech-lead.md).

- **Create the Run from the coordinator's own chat**, never from a subagent or another chat: a Run stays bound to
  the session that created it. `orca orchestration run-current --json` shows it (`.result.run` is `null` when there
  is none); `orca orchestration run-create --objective "<objective>" --json` creates one, and its id goes alone on
  one line into the run-id file.
- **Arm the wait.** Keep `orca orchestration check --run <own run id> --wait --timeout-ms 1800000 --json` running
  with Claude Code's Bash `run_in_background` and a Bash timeout above `--timeout-ms` (`1860000`), never a detached
  `&`: a chat wakes when its background command ends, and a detached process does not wake it.
- **Process, acknowledge, re-arm.** The wait returns the whole Delivery, every unacknowledged message of the Run,
  heartbeats included, with its id in `.result.deliveryId`. Act on every message, then acknowledge and re-arm in
  one command, also in the background:
  `orca orchestration check --run <own run id> --ack <delivery-id> --wait --timeout-ms 1800000 --json`. When a wait
  times out with nothing, re-arm it without `--ack`. A Run replays the same Delivery until it is acknowledged, so an
  unacknowledged batch hides newer mail.
- **When the wait is gone.** The harness can end a long background command, and Orca stops an idle chat's process
  after 30 minutes. Mail is not lost: Orca nudges an idle chat bound to a Run with a new prompt when mail arrives.
  That nudge is the fallback, not the rule. On a nudge, read with a plain `orca orchestration check --run <own run id> --json`, process, acknowledge with
  `--ack <delivery-id>` until `deliveryId` is `null`, then re-arm. See [gotchas](../docs/gotchas.md).
- **Send** by writing the body to a file in the sender's durable folder first, then:
  `orca orchestration send --to "run:$(cat <peer run-id file>)" --type status --subject "<prefix> <subject>" --body "$(cat <file>)"`.
  Subject prefixes: `[From Ideas]`, or `[From Ideas, product owner's decision]` when it carries one; `[Tech-lead]`
  from the tech lead. Read the peer's id from its file on every send: it changes when the peer creates a new Run.
- **Never type into another agent.** `orca terminal send` lands in the target's input box and overwrites what the
  human is typing there.
- **Who asks whom.** The tech lead never asks the product owner directly; product questions go to Ideas. Ideas
  brings the product owner one concrete decision at a time, with options, tradeoffs and a recommendation. A
  technical or reversible choice is taken and reported.
- **A surface change needs a new Run.** A chat cannot consume a Run created under another surface (a terminal) or
  by another chat session. Move only with no live or pending dispatches
  (`orca orchestration worker-list --run <old run id> --json`): workers keep mailing the old Run.

## Running a feature in Orca

The tech lead runs these from its own chat. The version-matched reference is `orca skills get orchestration`.

```bash
git -C <repo path> fetch origin   # then cut or update the integration branch from origin/<main-line>
test -s <tech-lead dir>/briefs/<brief>.md
orca orchestration worker-start \
  --spec "Your brief is the file <absolute path of the brief>. Read it whole first and follow it exactly." \
  --task-title "<task>" --worktree new-child --name <worktree-name> --repo name:<repo> \
  --base-branch <integration-branch> --agent claude --model <model> --effort <effort> \
  --deps '["<contract-task-id>"]' --json
```

- **Durable briefs.** Each brief is a file in `<tech-lead dir>/briefs/`, never under `/tmp`. Check it exists before
  `worker-start`: a missing file is passed to the worker as a bare path. Write its path in full in `--spec`; a `~`
  inside quotes is not expanded.
- **One worktree per work unit**, created from the feature's integration branch with `--worktree new-child`, so it
  nests under the tech lead's worktree. `<repo>` is the repository's Orca name (`repos[].name`). A worker started
  with `--worktree current` would share the tech lead's worktree.
- **Corrections** to a unit (review fixes, contract amendments, PRD changes) go in that unit's existing worktree, on
  the same branch: `worker-start --worktree path:<absolute path>` with no `--name`, `--repo` or `--base-branch`,
  which Orca refuses there. Never create a new worktree to correct a unit.
- **After `worker_done`** the dispatch is settled and cannot be reused; a follow-up is a new `worker-start` on the
  same worktree. Release a settled worker's terminal with
  `orca orchestration worker-release --dispatch <dispatch-id>` when the feature closes.
- **Answering workers.** A question: `orca orchestration reply --id <msg-id> --body "$(cat <file>)"`. A note to a
  live worker: `orca orchestration send --to dispatch:<dispatch-id> --subject "..." --body "$(cat <file>)"`. A
  heartbeat is a sign of life only.
- **Orca has no merge command:** `merge_ready` is only a message. PRs target the integration branch; the tech lead
  merges work units into it; only the product owner merges into a main branch
  ([delivery model](../docs/delivery-model.md)).
- **Monitors.** Before the first PR of a feature, the PR monitor and the worker watch run in the mode
  `orca.notify_mode` names (`run` sends to the tech lead's Run mailbox), as [`tools/README.md`](../tools/README.md)
  describes. The PR monitor covers every open PR the tech lead owns or hands to the product owner. The worker
  watch reports a pending permission prompt once per prompt; the tech lead reports each to Ideas at once, with the
  exact command and its read on whether it is safe, instead of waiting silently.

## Rules that keep the work moving

- Tasks depend on each other only through a real contract.
- A reversible decision is assumed and reported in the worker report, never a reason to stop.
- A product decision goes to the tech lead with `orca orchestration ask`. The tech lead answers it, or sends it to
  Ideas for the product owner, while the developer continues with what does not depend on it.
- A failing worker never stops the others. A failed task is a decision for the tech lead.
- Notes inform; they never approve. The only gates are the reviewer and the product owner, at the end.
- Tests: one end-to-end test per behaviour by default; a unit test where the brief names a critical piece. A
  repository's own stricter test rules win.
- A PR body follows the target repository's PR template, or the structure of its merged PRs where it has none.
  The reviewer treats a body that does not as a blocker.
- Base architecture is mandatory ([team conventions](./team-conventions.md#base-architecture)).

## Review and QA

- **Reviewer** ([card](./roles/reviewer/SKILL.md)): fresh context, read-only, runs the checks itself. One for every
  high-risk unit, per unit, with one correction round and a recheck limited to those blockers, never a new full
  review. When no unit was high risk, one reviewer on the integration branch before the integration PRs. High risk
  means a mistake would be hard to detect or undo, or reaches beyond the change: stored data and migrations, auth
  and permissions, contracts others consume, concurrency, delivery and infrastructure.
- **QA** ([card](./roles/qa/SKILL.md)) when the feature is complete or a screen changed: in the browser for screens,
  against the API for backend-only changes, on the integration branches running locally.
- What neither could verify goes into the product owner's [test plan](./templates/test-plan.md).

## Inventory and cleanup

- The tech lead keeps an inventory in Engram, topic `<prefix>/agents/tech-lead-inventory` (project
  `<engram project>`): its standing Run (id and objective), every worktree, worker terminal, tmux session,
  container, database and test-data path it opens, with where it lives, why, and when it is removed. It is updated
  on every open and every removal.
- After the product owner merges an integration branch into its main line, the tech lead checks that every
  worktree of the feature is clean (`git status --porcelain` empty, nothing unpushed) and removes them with
  `orca worktree rm --worktree <selector>`. Remote branches stay. A worktree that is not clean is reported, not
  removed.
- A worker's scratch under `~/.config/orca/chat-scratch/` can hold sensitive exports; it is deleted after use.

## Measure, then decide

- **Per-phase timing.** For every feature the tech lead records when each phase ended: PRD ready, contract, each
  unit's PR, review, QA, integration PRs ready. Times come from PR and message timestamps, not from memory, kept in
  `<tech-lead dir>/timing/<feature>.txt` and summarized in the feature's log in the hub.
- **Feature log.** Per feature: lane, roles, models and effort, wall time, cost when available, per-phase timing,
  reviewer and QA findings, what the product owner's test plan caught, and every case where a worker followed a
  global instruction over its brief. Seniority, cards and these rules change on that evidence.
- **Measure before deciding.** When a decision depends on numbers (time, memory, cost, size), measure them on the
  real setup first. A setting the measurement depends on is read, not assumed.

## Memory

- Every agent reads Engram with `project: "<engram project>"`, passed explicitly: Engram otherwise detects the
  project from the working directory, and a worker in another repository would read or write elsewhere.
- Ideas saves the product owner's decisions and its own mistakes. The tech lead writes role lessons and its
  inventory. Workers do not save; they report learnings in their report.
- A role lesson is written only with evidence (a failing test, a `file:line` verdict, a literal PRD quote, a
  decision of the product owner) and names it. Keys: `<prefix>/roles/<role>/<lesson-slug>`, plus one
  `<prefix>/roles/<role>/index` listing the active lessons. A brief passes the index, so the worker reads exact
  lessons instead of searching.
- A lesson comes from a specific case and is passed to briefs as that specific pattern, never as a general
  restriction. A lesson that turns out wrong is replaced, and the index drops it.
- A lesson moves into a role card only when it prevented a repeat of its failure in a later feature, recorded in
  the feature log, and the product owner approves the card change.

## One-time setup per repository

Local and reversible; nothing reaches the repository's history. Register every repository in Orca
(`orca repo add --path <repo path> --json`) so `worker-start --repo name:<repo>` resolves it. If gentle-ai is
installed (optional), exclude its local state and turn its own review off in every clone a worker uses, because
the team's reviewer replaces it and its consent prompts stop an unwatched worker:

```bash
printf 'odd/\n.atl/\n' >> <repo path>/.git/info/exclude
gentle-ai review mode disable --scope clone --cwd <repo path>
```

Inside an Orca dispatch the brief takes precedence over any global instruction a worker has loaded: questions go
through `orca orchestration ask`, never an interactive menu; the base branch is the integration branch; the test
policy is the one above; workers open no issues and save no memory.
