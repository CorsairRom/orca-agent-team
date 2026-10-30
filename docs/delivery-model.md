# Delivery model

How work moves from a request to the main branch of each repository, who decides what, and who merges what. This is
the template's **default** workflow; the `delivery:` and `conventions:` sections of `config/stack.yaml` adapt it
([Configuring it](#configuring-it)). The roles and their rules are in [`agents/README.md`](../agents/README.md) and
the cards under [`agents/roles/`](../agents/roles/).

## One integration branch per feature

By default, every feature reaches a repository's main branch through **one branch**: the feature's integration
branch in that repository. Nothing of the feature lands on the main branch until the whole feature is complete and
tested.

```
main branch (repos[].main_branch in the config)
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
- **Only the product owner merges into the main branch.** There is one integration PR per repository. The product
  owner tests the feature on the integration branches and merges.
- **No other agent merges anything.** Workers never merge, rebase or update a shared integration branch.

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

- **Identities, not chats.** Ideas and the Tech-lead are permanent chats. Every other role is a role card,
  instantiated as an Orca worker for one work unit and released when the unit closes.
- **Three lanes, chosen at triage.** *Small*: a question or a contained fix; one developer, no PRD. *Bounded*: one
  repository; a brief, one developer, the reviewer, QA when a screen changes. *Wide*: several repositories or a
  large change; a PRD, a contract task first, parallel developers only under the rule below, the reviewer on the
  integrated result, QA.
- **Seniority is model plus effort**, chosen per work unit from `models` in the config.
- **One authority per coupled decision.** Developers write in parallel only when the Tech-lead has written a
  contract with file ownership first, the units share no files or shared registries (routes, dependencies,
  configuration), each interface change is announced to the others, and the merged result is verified. Otherwise
  they work in series.
- **Nothing blocks unless it must.** A reversible decision is assumed and reported in `worker_done`. A product
  decision goes to the Tech-lead, which answers or batches it to Ideas, and Ideas brings the product owner one
  decision at a time, while the developer continues with what does not depend on it. A failing worker never stops
  the others. Readers deliver notes, never approvals. The only gates are the reviewer and the product owner.
- **Each repository's own structure.** Workers follow each repository's existing structure and patterns. A
  stricter rule, such as a Tech-lead decision before any new library, goes in `conventions:`.
- **Review and QA.** An independent reviewer with a fresh context runs the tests and the build and checks the
  result against the PRD: per work unit for high-risk units, otherwise once on the integration branch before the
  integration PRs open. QA exercises the real local path when a screen or an API changed.
- **The product owner accepts with a short test plan**: the few steps where an agent decided something on its own,
  built from the assumptions each worker reported, numbered and with the expected result
  ([template](../agents/templates/test-plan.md)).
- **Memory.** The Tech-lead writes the lessons of a role's memory, each with the evidence behind it (a failing
  test, a `file:line`, a quote from the PRD, a decision of the product owner). Who saves, and why, is in
  [`agents/README.md`](../agents/README.md#memory); the lesson layout is a default.

Orca provides Runs, workers, typed messages, blocking questions and decision gates, but no scheduler, reviewer,
memory or merge command, so the team supplies those.

## Configuring it

Two sections of `config/stack.yaml` adapt the workflow; the commented example is
[`config/stack.example.yaml`](../config/stack.example.yaml).

```yaml
delivery:
  integration_branch_per_feature: true   # work-unit PRs go into one integration branch per feature
  owner_merges_main: true                # only the product owner merges into the main branch, after testing
conventions: []                          # free-form team rules the Tech-lead passes into every brief
```

| Key | Default | What it changes |
| --- | --- | --- |
| `delivery.integration_branch_per_feature` | `true` | `true`: the workflow above. `false`: work-unit PRs target the repository's main branch, and there is no integration PR. The Tech-lead fills each brief's `<target branch>` from it |
| `delivery.owner_merges_main` | `true` | `true`: only the product owner merges into a main branch. `false`: the Tech-lead also merges into the main branch once the checks pass and the reviewer approved |
| `conventions` | empty | A list of one-line rules of the team, such as `"Feature flags gate every new module."` The Tech-lead puts the list in every brief, and every worker follows it. An entry also changes a [template default](../agents/README.md#template-defaults). A new project starts with none; the config example shows more entries as comments |

Rules that belong to one team, such as a test policy, a branching rule or a review checklist, go in
`conventions:`, not in the role cards. The env file carries these keys
([Writing the env file](../tools/README.md#writing-the-env-file)).
