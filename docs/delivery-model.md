# Delivery model

How work moves from a request to the main branch of each repository, who decides what, and who merges what. The
roles and their rules are in [`agents/README.md`](../agents/README.md) and the cards under
[`agents/roles/`](../agents/roles/); this page explains the model and the reasons behind it.

## One integration branch per feature

Every feature reaches a repository's main branch through **one branch**: the feature's integration branch in that
repository. Nothing of the feature lands on the main branch until the whole feature is complete and tested.

```
main branch (main, develop, ... as the config says)
 └─ feature integration branch, cut from the fresh main branch
     ├─ work-unit PR 1 → integration branch   (merged by the Tech-lead)
     ├─ work-unit PR 2 → integration branch   (merged by the Tech-lead)
     └─ ...
 integration PR → main branch                 (merged by the product owner, after testing)
```

- **Work-unit PRs** target the integration branch, directly or chained into each other. Each is one unit of
  behaviour with its tests and docs, written by one worker in one worktree.
- **The Tech-lead merges work units** into the integration branch once their checks pass and, when required, the
  reviewer approved them.
- **Only the product owner merges into the main branch.** There is one integration PR per repository. The
  Tech-lead opens it **ready for review**, not as a draft, and states the deploy order when several repositories
  are involved. The product owner tests the feature on the integration branches, merges, and decides the deploy.
- **No other agent merges anything.** Workers never merge, rebase or update a shared integration branch.
- **A feature that must stay dark** after the merge, such as a new module, sits behind a flag. The flag gates every
  entry point of the module (routes, navigation, access rules, endpoints), a test proves the module is absent with
  the flag off, migrations only add the module's own tables, and turning the flag on in production is the product
  owner's decision. The single integration PR still applies: a flag does not let work units reach the main branch.

Consequences: the main branch receives a feature once, complete, after the product owner's test. A defect found
after the merge comes back as a new request.

## No work starts on a stale base

Before a feature starts, the Tech-lead runs `git fetch origin` in each target repository and cuts (or updates) the
feature's integration branch from the fresh remote main branch named in the config (`repos[].main_branch`).

Before a worker starts, it fetches and checks that its base contains the latest remote main branch, for example
`git merge-base --is-ancestor origin/<main branch> HEAD`. If it does not, the worker does not start: it asks the
Tech-lead with `orca orchestration ask`, and the Tech-lead brings the integration branch up to date. The check and
its result appear in the worker's `worker_done` report.

## The team and its lanes

The work runs as a software team made of agents, coordinated on Orca from the hub repository.

```
product owner ── talks only to Ideas
 └─ Ideas · a PRD, or a reasoned discard
 └─ Tech-lead · triage → lane → seniority → one brief per work unit
      ├─ readers (read-only, deliver a note, never block)
      ├─ developers (Orca workers, one per work unit)
      ├─ reviewer (fresh context, runs the checks)
      └─ QA (when a screen or an API changed)
 └─ test plan for the product owner ── integration PR → main branch
```

- **Identities, not chats.** Ideas and the Tech-lead are permanent chats. Every other role is a role card plus its
  memory topic, instantiated as an Orca worker for one work unit and released when the unit closes.
- **Three lanes, chosen at triage.** *Small*: a question or a contained fix; one developer, no PRD. *Bounded*: one
  repository; a brief, one developer, the reviewer, QA when a screen changes. *Wide*: several repositories or a
  large change; a PRD, a contract task first, parallel developers only under the rule below, the reviewer on the
  integrated result, QA.
- **Seniority is model plus effort**, chosen per work unit from `models` in the config. Before adding writers,
  raise the effort of one.
- **One authority per coupled decision.** Developers write in parallel only when the Tech-lead has written a
  contract with file ownership first, the units share no files or shared registries (routes, migrations,
  dependencies, flags), each interface change is announced to the others, and the merged result is verified.
  Otherwise they work in series.
- **Nothing blocks unless it must.** A reversible decision is assumed and reported in `worker_done`. A product
  decision goes to the Tech-lead, which answers or batches it to Ideas, and Ideas brings the product owner one
  decision at a time, while the developer continues with what does not depend on it. A failing worker never stops
  the others. Readers deliver notes, never approvals. The only gates are the reviewer and the product owner.
- **Respect each repository's architecture.** Workers reuse the existing infrastructure: HTTP clients, auth,
  permissions, flags, data access, shared components, configuration and CI. New shared infrastructure or anything
  that crosses domains needs an explicit decision by the Tech-lead first; the reviewer treats a violation as a
  blocker.
- **Review and QA.** An independent reviewer with a fresh context runs the tests and the build and checks the
  result against the PRD: per work unit for high-risk units, otherwise once on the integration branch before the
  integration PRs open. QA exercises the real local path when a screen or an API changed.
- **The product owner accepts with a short test plan**: the few steps where an agent decided something on its own,
  built from the assumptions each worker reported, numbered and with the expected result
  ([template](../agents/templates/test-plan.md)).
- **Memory is curated by the Tech-lead.** Only the Tech-lead writes a role's memory, only with evidence (a failing
  test, a `file:line` verdict, a quote from the PRD, a decision of the product owner). A lesson reaches a role card
  only after it shows a measured gain.

Why this shape: parallel writers only match a single agent when one authority writes a contract with file
ownership first, and they cost more; raising one agent's effort often gains more than adding a team. Curated memory
helps where self-written memory does not. A fresh-context reviewer that runs the checks is the review pattern with
evidence behind it. Orca provides Runs, workers, typed messages, blocking questions and decision gates, but no
scheduler, reviewer, memory or merge command, so the team supplies those.

## When gentle-ai is installed

gentle-ai is optional. When it is installed, it is **not modified**: the workflow adds its own rules on top, and
inside an Orca dispatch the worker's brief takes precedence over gentle-ai's global instructions. gentle-ai is
adapted only where one of its rules demonstrably fails, and only through a recorded decision in the hub.

| gentle-ai piece | In an Orca worker |
| --- | --- |
| ODD (its task tracking) | On. It is the developer's own board. Orca's tasks stay the team board, and `worker_done` is the only report the Tech-lead reads |
| RDD (its native review) | Off in every clone a worker uses. Its consent prompts would stop a worker nobody is watching; the team's reviewer and QA replace it |
| Engram | On, with the project key from `memory.engram_project` passed explicitly on every call, because Engram otherwise detects the project from the worker's directory |
| `odd/` and `.atl/` | Never committed: each repository lists them in its local `.git/info/exclude` |

Per-clone setup, once per non-hub repository (`<path>` is its local path from the config):

```bash
printf 'odd/\n.atl/\n' >> <path>/.git/info/exclude
gentle-ai review mode disable --scope clone --cwd <path>
gentle-ai review mode status --cwd <path>
```

Expected: the last line reports receipt-driven development off, decided by the clone. Both changes are local,
reversible and outside the repository's history, which is why they are used instead of editing gentle-ai.

Inside an Orca dispatch the brief overrides gentle-ai on these points:

1. **Questions** go through `orca orchestration ask`, never an interactive menu.
2. **The base branch** is the feature's integration branch, and PRs target it.
3. **Tests** follow the brief, not gentle-ai's own test policy.
4. **No issues** are opened against gentle-ai or any other project from a worker.
5. **Memory** is written by the Tech-lead. A worker reports its learnings in `worker_done` and does not save them.

Check that these switches still hold after every `gentle-ai sync`. The rules are probabilistic: a model may still
follow the global text over the brief, so the Tech-lead records every such case, and repeated failures are the
evidence for adapting that one piece.
