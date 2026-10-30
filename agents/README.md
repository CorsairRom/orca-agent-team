# Operating manual

How a request travels from the product owner to merged code through a team of agents coordinated on Orca. This
folder is the manual every agent of the team reads: the roles, the lanes, seniority, how the two permanent chats
talk, how workers are dispatched, and the rules for review, QA, memory and cleanup.

| Read | For |
| --- | --- |
| [`team-conventions.md`](./team-conventions.md) | The general rules for everything an agent writes: languages, PRs and commits, commands, files |
| [`roles/`](./roles/) | One card per role: [Ideas](./roles/ideas/SKILL.md), [tech lead](./roles/tech-lead/SKILL.md), [reviewer](./roles/reviewer/SKILL.md), [QA](./roles/qa/SKILL.md), and one developer card per repository kind |
| [`templates/`](./templates/) | [PRD](./templates/prd.md), [brief](./templates/brief.md), [worker report](./templates/worker-report.md), [test plan](./templates/test-plan.md), and the after-start checklists of [Ideas](./templates/after-start-ideas.md) and the [tech lead](./templates/after-start-tech-lead.md) |
| [`../docs/delivery-model.md`](../docs/delivery-model.md) | The default delivery: one integration branch per feature, work-unit PRs, who merges |
| [`../docs/setup-guide.md`](../docs/setup-guide.md) | Building the whole setup on a machine |
| [`../docs/reboot.md`](../docs/reboot.md) | What to do after a reboot or a chat reopen |
| [`../docs/gotchas.md`](../docs/gotchas.md) | Orca and Claude Code behaviours that break the workflow if ignored |
| [`../tools/README.md`](../tools/README.md) | The PR monitor and the worker permission watch |
| [`../config/stack.example.yaml`](../config/stack.example.yaml) | The stack's configuration: repositories, hub layout, delivery, conventions, memory, languages, models, Orca settings |

## Placeholders

This is the only placeholder table; every other file links here. The cards, templates and docs are stack-agnostic.
Wherever they show a `<...>` placeholder, use its value; a bash block uses the env-file key beside it instead
([Writing the env file](../tools/README.md#writing-the-env-file) lists every key).

In the "Who fills it" column, **config** means the human sets the value in `config/stack.yaml` (bootstrap step 2,
or a later config change), and **env file** means the chat that writes the env file derives it (bootstrap step 3,
and again after every config change).

| Placeholder or key | Meaning | Who fills it | When |
| --- | --- | --- | --- |
| `<stack.id>`, `STACK_ID` | `stack.id`, such as `acme`; it names the local-share tree `~/.local/share/<stack.id>/` | Config | Install |
| `<stack.name>`, `STACK_NAME` | `stack.name`, the display name, such as `ACME platform` | Config | Install |
| `<hub path>`, `HUB_PATH` | The local clone of the repository of kind `hub`: Ideas and the tech lead work in its worktrees, and it keeps the planning documents | Config | Install |
| `<hub.prds_dir>`, `<hub.decisions_dir>`, `<hub.backlog_file>`; `HUB_PRDS_DIR`, `HUB_DECISIONS_DIR`, `HUB_BACKLOG_FILE` | Where the hub keeps PRDs, decisions and the backlog, relative to the hub (defaults `docs/prd`, `docs/decisions`, `BACKLOG.md`) | Config | Install |
| `<repo path>`, `REPO_<i>_PATH` | A repository's local clone, from `repos[]` | Config | Install |
| `<main-line>`, `REPO_<i>_MAIN_BRANCH`, `HUB_MAIN_BRANCH` | A repository's `main_branch` in `repos[]`, usually `main` | Config | Install |
| `<engram project>`, `ENGRAM_PROJECT` | `memory.engram_project`: the Engram project key every chat and worker uses | Config | Install |
| `<prefix>`, `TOPIC_PREFIX` | `memory.topic_prefix`: the first segment of every topic key | Config | Install |
| `<model>`, `<effort>`; `MODEL_<KEY>`, `EFFORT_<KEY>` | A role's or a seniority level's `models.<key>.model` and `.effort` | Config | Install |
| `<team repo>`, `TEAM_REPO` | The local clone of this repository | Env file | Install |
| `<ideas dir>`, `IDEAS_DIR` | `~/.local/share/<stack.id>/ideas`: Ideas' durable folder | Env file | Install |
| `<tech-lead dir>`, `TECH_LEAD_DIR` | `~/.local/share/<stack.id>/tech-lead`: the tech lead's durable folder | Env file | Install |
| `<bootstrap dir>`, `BOOTSTRAP_DIR` | `~/.local/share/<stack.id>/bootstrap`: the installing chat's folder | Env file | Install |
| `<ideas run-id file>`, `IDEAS_RUN_ID_FILE` | `<ideas dir>/run-id.txt`, holding Ideas' Run id, only the id, on one line | The path: env file. The id: Ideas | Ideas' first turn, and whenever it creates a new Run |
| `<tech-lead run-id file>`, `TECH_LEAD_RUN_ID_FILE`, `RUN_ID_FILE` | `<tech-lead dir>/run-id.txt`, holding the tech lead's Run id; the monitors send to it | The path: env file. The id: the tech lead | The tech lead's first turn, and whenever it creates a new Run |
| `<own run id>` | The id in the reading chat's own run-id file | The chat, with `cat` | Every mailbox check |
| `<peer run-id file>` | The other permanent chat's run-id file | The chat | Every send |
| `<deliveryId>` | `.result.deliveryId` of the last plain `orca orchestration check` | The chat | Every mailbox check |
| `<ideas worktree>`, `<tech-lead worktree>` | Absolute paths of the two hub worktrees, read from the `orca worktree create --json` output: Orca chooses where they live | The installing chat | Bootstrap step 5 |
| `<target branch>` | The branch a work unit starts from and its PR targets, per repository: the feature's integration branch when `DELIVERY_INTEGRATION_BRANCH_PER_FEATURE` is `true`, the repository's main branch when it is `false` | The tech lead, in each brief | Each brief |
| `<dispatch-id>`, `<task-id>` | A worker's ids, from the JSON `worker-start` prints or from `orca orchestration worker-list --json` | The tech lead | Each dispatch |
| `<file>` | A message body file in the sender's durable folder, never under `/tmp` | The sender | Each message |
| `<token>` | A fresh round-trip token: `BOOT-` plus the Unix time at install, `PONG-<n>` with a new `<n>` on each resume | The sender of the test message | Each round trip |

Any other `<...>` in a template, such as `<slug>`, `<task title>` or `<command>`, is filled by whoever writes that
document, as it writes it.

## The team

```
Product owner ── talks only to Ideas
 └─ Ideas · Claude Code in an Orca chat, in a hub worktree
      ├─ its own Run: an inbox, id in <ideas run-id file>
      ├─ its own Claude subagents: read-only research
      └─ Run-to-Run mail, never a worker relation
          └─ Tech lead · Claude Code in an Orca chat, in a hub worktree
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
   [`templates/prd.md`](./templates/prd.md) into `<hub path>/<hub.prds_dir>/`, or a reasoned discard.
2. **The tech lead triages it**: type, repositories, lane and seniority. It rejects work outside the stack's
   repositories (`repos[]`), with the reason.
3. **The tech lead plans the feature in Orca**: in its standing Run, one task per work unit, a contract task first
   when repositories depend on each other, and one brief per task from [`templates/brief.md`](./templates/brief.md).
4. **Workers deliver** with `worker_done` and a report from [`templates/worker-report.md`](./templates/worker-report.md),
   including every assumption they made.
5. **The reviewer, then QA when warranted**: an independent reviewer for every high-risk unit, or, when no unit was
   high risk, one reviewer on the integrated result before it goes to the product owner.
6. **The tech lead hands the product owner a test plan** from [`templates/test-plan.md`](./templates/test-plan.md),
   through Ideas. With the default delivery, the product owner tests and merges into each repository's main branch.

## Delivery

The template's default workflow is set in the `delivery:` section of the config; the
[delivery model](../docs/delivery-model.md) describes it in full.

- `delivery.integration_branch_per_feature: true` (default): each feature gets one integration branch per target
  repository, cut from the fresh main line; every work unit opens its PR into it, and the tech lead merges work-unit
  PRs once their checks pass.
- `delivery.owner_merges_main: true` (default): only the product owner merges into a main branch, after testing.
  No other agent merges into a main branch.

Wherever a card or a template says `<target branch>`, the tech lead fills it in the brief from
`DELIVERY_INTEGRATION_BRANCH_PER_FEATURE`: the feature's integration branch in that repository when `true`, the
repository's main branch when `false`.

## Conventions

A team's own rules (a test policy, a migration rule, a commit trailer policy, how new modules are switched on) are
not part of this template. They go in the free-form `conventions:` list of the config, which a new project starts
empty. The tech lead copies every entry into the "Team conventions" section of each brief, and every agent applies
them like any rule of its card. [`team-conventions.md`](./team-conventions.md) holds only the general rules every
team needs, and is appended to every brief. The [config example](../config/stack.example.yaml) shows rules some
teams use, as commented entries of `conventions:`.

## Template defaults

These numbers and wordings are the template's defaults. Change them with `conventions:`: an entry that says
otherwise wins over the default here.

- A worker blocked for more than 15 minutes on the same thing asks the tech lead.
- Ideas asks the product owner at most five questions per request.
- The reviewer allows one correction round per unit; the recheck after it covers only those blockers, and anything
  still open goes to the tech lead as a decision.
- Every report about a PR says where it goes, as `→ <target branch>`, such as `→ feat/<slug>` or `→ main`.

## Mandatory before any work

No work starts on a stale base.

- **Feature start:** the tech lead runs `git fetch origin` on each target repository and, when `<target branch>` is
  the feature's integration branch, cuts (or updates) it from the fresh `origin/<main-line>`.
- **Worker start:** every worker runs `git fetch origin` and checks its base holds the latest main line:
  `git merge-base --is-ancestor origin/<main-line> HEAD`. If it does not, it does not start: it asks the tech lead
  with `orca orchestration ask`. The tech lead brings the base up to date; workers never rebase or update
  `<target branch>` themselves.
- The check and its result appear in the worker report under Verification.

## Roles

Each role is a card under [`roles/`](./roles/). A developer card exists per repository kind (`repos[].kind`); a
repository of kind `other` uses the closest card, and the brief names the differences. The repository of kind `hub`
uses the `dev-docs` card.

| Role | Card | Writes | Runs as | Seniority |
| --- | --- | --- | --- | --- |
| Ideas | [ideas](./roles/ideas/SKILL.md) | PRDs in the hub, never code | Permanent chat | `models.ideas` |
| Tech lead | [tech-lead](./roles/tech-lead/SKILL.md) | Briefs, test plans, hub notes, never product code | Permanent chat | `models.tech_lead` |
| Frontend developer | [dev-frontend](./roles/dev-frontend/SKILL.md) | Repositories of kind `frontend` | Orca worker | Per task |
| Backend developer | [dev-backend](./roles/dev-backend/SKILL.md) | Repositories of kind `backend` | Orca worker | Per task |
| Docs developer | [dev-docs](./roles/dev-docs/SKILL.md) | Repositories of kind `docs` | Orca worker | Per task |
| Infrastructure developer | [dev-infra](./roles/dev-infra/SKILL.md) | Repositories of kind `infra`, and CI, containers or deployment in any repository | Orca worker | Per task |
| Reviewer | [reviewer](./roles/reviewer/SKILL.md) | A verdict | Orca worker | Per task |
| QA | [qa](./roles/qa/SKILL.md) | A QA report | Orca worker | Per task |

**Notes before code.** Two kinds of note are written by workers dispatched with a brief, not by a dedicated
card, and they never block a developer:

- **Contract** (wide feature, in the hub): API endpoints and schemas with examples, file ownership per task, the
  shared registries (routes, migrations, dependencies, configuration) each task may touch and who owns each, and the
  order in which interface changes land. It is also the only route for anything new that crosses domains: it says
  whether the existing infrastructure covers it, or states it as a decision for the tech lead.
- **Screen note** (any task that changes a screen, read-only): the existing components and patterns to reuse, with
  paths and the reference screen; the vocabulary and copy for every new label, in `language.app_copy`; the states to
  cover (empty, loading, error, no permission); what not to invent. At most one page, sent to the frontend developer
  with `orca orchestration send` and in the report.

## Lanes

| Lane | When | Who takes part |
| --- | --- | --- |
| Small | A question, or a fix contained in one place | One developer · reviewer |
| Bounded feature | One repository | Brief · one developer · screen note if a screen changes · reviewer · QA if a screen changes |
| Wide feature | Several repositories, or a large change | PRD · contract task first · developers in parallel only under the conditions below · screen notes · reviewer per high-risk unit, else on the integrated result · QA |

**Parallel developers** need all of these, or they work in series:

- the tech lead wrote a contract with file ownership before splitting the work;
- the units share no files and no shared registries (routes, migrations, dependencies, configuration);
- each finished interface change is announced to the other running developers;
- the merged result is verified by the reviewer;
- a coupled change is written by a single worker.

## Seniority

Seniority is agent + model + effort, chosen per task by the tech lead from the levels in `models`. The table is
the template's default reading of each level; change it to suit the team.

| Level | Config key | Default use |
| --- | --- | --- |
| Senior | `models.senior` | Contract tasks, coupled or cross-repository changes, infrastructure, review |
| Mid | `models.mid` | A bounded feature in one repository, screen notes, QA |
| Junior | `models.junior` | Mechanical work: docs, renames, a test of a known shape |

Ideas and the tech lead use `models.ideas` and `models.tech_lead`. A worker can run another Orca agent
(`worker-start --agent`, such as `codex` or `opencode`) when that agent reads its role card and reaches Engram with
`<engram project>`.

## The Run mailboxes

Ideas and the tech lead are both Orca chats, each the top-level coordinator of its own Run, with its id in its own
run-id file. They talk only through those Runs. The steps that set this up are the two after-start checklists:
[Ideas'](./templates/after-start-ideas.md) and the [tech lead's](./templates/after-start-tech-lead.md).

- **Create the Run from the coordinator's own chat**, never from a subagent or another chat. A Run is bound to the
  session that created it; another session cannot read its mailbox or dispatch under it
  ([gotchas](../docs/gotchas.md#a-run-is-bound-to-the-session-that-created-it)).
  `orca orchestration run-current --json` shows the bound Run (`.result.run` is `null` when there is none);
  `orca orchestration run-create --objective "<objective>" --json` creates one, and its id goes alone on one line
  into the run-id file.
- **Receive** by [the mailbox rule](#the-mailbox-rule) below.
- **Send** by writing the body to a file in the sender's durable folder first, then:
  `orca orchestration send --to "run:$(cat <peer run-id file>)" --type status --subject "<prefix> <subject>" --body "$(cat <file>)"`.
  Subject prefixes: `[From Ideas]`, or `[From Ideas, product owner's decision]` when it carries one; `[Tech-lead]`
  from the tech lead. Read the peer's id from its file on every send: it changes when the peer creates a new Run.
- **Never type into another agent.** `orca terminal send` lands in the target's input box and overwrites what the
  human is typing there.
- **Who asks whom.** The tech lead never asks the product owner directly; product questions go to Ideas. Ideas
  brings the product owner one concrete decision at a time, with options, tradeoffs and a recommendation. A
  technical or reversible choice is taken and reported.

### The mailbox rule

This is the only copy of the rule; every other file links here.

When new mail arrives in a Run, Orca injects a prompt into the idle chat bound to that Run: "You have N
orchestration message(s). Run `orca orchestration check --run <run-id>`." An idle chat with no background command
wakes on it ([gotchas](../docs/gotchas.md#orca-prompts-an-idle-chat-when-its-run-gets-mail)). Whether the prompt
also reaches a chat that the Chat UI idle sweep has closed is `(unverified)`.

On that prompt, and whenever the chat starts or resumes:

1. `orca orchestration check --run <own run id> --json`;
2. read EVERY message of the Delivery, heartbeats included;
3. act on each;
4. acknowledge: `orca orchestration check --run <own run id> --ack <deliveryId> --json`. The answer is the next
   Delivery; repeat from 2 until `deliveryId` is `null`.

No background wait. A Run replays the same Delivery until it is acknowledged, so an unacknowledged batch hides
newer mail ([gotchas](../docs/gotchas.md#a-run-replays-a-delivery-until-it-is-acknowledged)). `<own run id>` is
the id in the chat's own run-id file: `$(cat "$IDEAS_RUN_ID_FILE")` for Ideas, `$(cat "$TECH_LEAD_RUN_ID_FILE")`
for the tech lead.

## Running a feature in Orca

The tech lead runs these from its own chat. The version-matched reference is `orca skills get orchestration`.

```bash
git -C <repo path> fetch origin   # an integration branch as <target branch>: cut or update it from origin/<main-line>
test -s <tech-lead dir>/briefs/<brief>.md
orca orchestration worker-start \
  --spec "Your brief is the file <absolute path of the brief>. Read it whole first and follow it exactly." \
  --task-title "<task>" --worktree new-child --name <worktree-name> --repo path:<repo path> \
  --base-branch <target branch> --agent claude --model <model> --effort <effort> \
  --deps '["<contract-task-id>"]' --json
```

- **Durable briefs.** Each brief is a file in `<tech-lead dir>/briefs/`, never under `/tmp`. Check it exists before
  `worker-start`: a missing file is passed to the worker as a bare path. Write its path in full in `--spec`; a `~`
  inside quotes is not expanded.
- **One worktree per work unit**, created from `<target branch>` with `--worktree new-child`, so it
  nests under the tech lead's worktree. `<repo path>` is the repository's local clone (`REPO_<i>_PATH`); Orca
  selects a repository by path, so its display name never matters. A worker started
  with `--worktree current` would share the tech lead's worktree.
- **Corrections** to a unit (review fixes, contract amendments, PRD changes) go in that unit's existing worktree, on
  the same branch: `worker-start --worktree path:<absolute path>` with no `--name`, `--repo` or `--base-branch`.
  Never create a new worktree to correct a unit.
- **After `worker_done`** the dispatch is settled and cannot be reused; a follow-up is a new `worker-start` on the
  same worktree. Release a settled worker's terminal with
  `orca orchestration worker-release --dispatch <dispatch-id>` when the feature closes.
- **Answering workers.** A question: `orca orchestration reply --id <msg-id> --body "$(cat <file>)"`. A note to a
  live worker: `orca orchestration send --to dispatch:<dispatch-id> --subject "..." --body "$(cat <file>)"`. A
  heartbeat is a sign of life only.
- **Orca has no merge command:** `merge_ready` is only a message. Merges follow the configured
  [delivery](#delivery).
- **Monitors.** Before the first PR of a feature, the PR monitor and the worker watch run in the tmux sessions
  `<stack.id>-pr-monitor` and `<stack.id>-worker-watch` and post to the tech lead's Run mailbox, as
  [`tools/README.md`](../tools/README.md) describes. The PR monitor covers every open PR the tech lead owns or hands
  to the product owner. The worker watch reports a worker waiting on a prompt only a human can answer once per prompt,
  and a worker it cannot observe; the tech lead reports each wait to Ideas at once, with the exact prompt and its
  read on whether it is safe, instead of waiting silently.

## Rules that keep the work moving

- Tasks depend on each other only through a real contract.
- A reversible decision is assumed and reported in the worker report, never a reason to stop.
- A product decision goes to the tech lead with `orca orchestration ask`. The tech lead answers it, or sends it to
  Ideas for the product owner, while the developer continues with what does not depend on it.
- A failing worker never stops the others. A failed task is a decision for the tech lead.
- Notes inform; they never approve. The only gates are the reviewer and the product owner, at the end.
- Tests follow the target repository's own test rules and any test rule in `conventions:`.
- Every agent follows each repository's existing structure and patterns
  ([team conventions](./team-conventions.md#each-repositorys-own-structure)).

## Review and QA

- **Reviewer** ([card](./roles/reviewer/SKILL.md)): fresh context, read-only, runs the checks itself. One for every
  high-risk unit, per unit, with the correction rounds of the [template defaults](#template-defaults) and a recheck
  limited to those blockers, never a new full review. When no unit was high risk, one reviewer on the integrated
  result before it goes to the product owner.
  High risk means a mistake would be hard to detect or undo: stored data, permissions, interfaces others use,
  concurrency, release.
- **QA** ([card](./roles/qa/SKILL.md)) when the feature is complete or a screen changed: in the browser for screens,
  against the API for backend-only changes, in the environment the brief names.
- What neither could verify goes into the product owner's [test plan](./templates/test-plan.md).

## Inventory and cleanup

- The tech lead keeps an inventory of everything it opens: its standing Run (id and objective), every worktree,
  worker terminal, tmux session, container, database and test-data path, with where it lives, why, and when it is
  removed. It is updated on every open and every removal. By default it lives in Engram, topic
  `<prefix>/agents/tech-lead-inventory` (project `<engram project>`); change it freely.
- When a feature is merged into its main line, the tech lead checks that every worktree of the feature is clean
  (`git status --porcelain` empty, nothing unpushed) and removes them with `orca worktree rm --worktree <selector>`.
  Remote branches stay. A worktree that is not clean is reported, not removed.
- Scratch files live outside every repository and are deleted after use.

## Memory

- Every agent passes `project: "<engram project>"` explicitly on every Engram call: Engram otherwise detects the
  project from the working directory, which in a hub worktree may be ambiguous, and a worker in another repository
  would read or write elsewhere. Engram, at the minimum version in the [README](../README.md#prerequisites),
  refuses an explicit project it holds no observation of (`unknown_project`), so the installing chat creates the
  project once, with `engram save ... --project`
  ([bootstrap step 5](../BOOTSTRAP_PROMPT.md#step-5-create-the-durable-folders-the-engram-project-and-the-two-hub-worktrees)).
  No agent asks which project or picks one from `mem_current_project`; this wins over any general memory
  instruction.
- **Workers do not save to shared memory; the tech lead does.** This is a fixed design rule, not a default: the
  shared memory stays curated, holding only lessons the tech lead has checked against their evidence. Workers put
  their learnings in their report. Ideas saves the product owner's decisions; the tech lead writes role lessons and
  its inventory.
- **Role lessons (a default; change it).** A lesson is written with its evidence (a failing test, a `file:line`
  verdict, a PRD quote, a decision of the product owner) under `<prefix>/roles/<role>/<lesson-slug>`, and listed in
  `<prefix>/roles/<role>/index`. A brief names the index, so the worker reads exact lessons instead of searching. A
  lesson that turns out wrong is replaced, and the index drops it. A lesson becomes part of a role card only with the
  product owner's approval.

## One-time setup per repository

Local and reversible; nothing reaches the repository's history. Register every repository in Orca
(`orca repo add --path <repo path> --json`) so `worker-start --repo path:<repo path>` resolves it. When the workers'
agents load global instructions or plugins, follow
[the setup guide](../docs/setup-guide.md#if-your-agents-load-global-instructions-or-plugins).

Inside an Orca dispatch the brief takes precedence over any global instruction a worker has loaded: questions go
through `orca orchestration ask`, never an interactive menu; the base branch is the brief's `<target branch>`; the
brief's team conventions apply; memory follows [Memory](#memory).
