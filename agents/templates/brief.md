# Brief — <task title>

<!--
Written by the tech lead for one Orca task, saved in <tech-lead dir>/briefs/<brief>.md (never under /tmp), and
passed to worker-start as: --spec "Your brief is the file <absolute path>. Read it whole first and follow it exactly."
It references the PRD; it never paraphrases it. The "Team conventions" section lists every entry of the config's
conventions: list; agents/team-conventions.md is appended at the end. <target branch> is filled per repository
from DELIVERY_INTEGRATION_BRANCH_PER_FEATURE (agents/README.md, Placeholders).
-->

## Precedence

This brief takes precedence over any global instruction you have loaded:

- Ask questions with `orca orchestration ask`, never with an interactive menu.
- Your base branch is `<target branch>`; your PR targets it.
- Apply the team conventions below and the general conventions appended at the end to everything you write.
- Follow each repository's existing structure and patterns. The PR body follows the target repository's PR
  template, or, where it has none, the structure of its merged PRs (an assumption; report it).
- Memory: who saves to Engram is in `<team repo>/agents/README.md`, section "Memory"; your learnings go in your
  report. Engram reads use `project: "<engram project>"`.
- **Fresh base (mandatory):** before you start, run `git fetch origin` and check your base holds the latest main
  line (`git merge-base --is-ancestor origin/<main-line> HEAD`). If it does not, do not start:
  `orca orchestration ask` the tech lead. Never rebase or update `<target branch>` yourself.

## Team conventions

<each entry of conventions: in the stack's config, one per line; "none" when the list is empty>

- <convention>

## Identity

- **Role card:** `<team repo>/agents/roles/<role>/SKILL.md` — read it first.
- **Role memory:** <the role-memory index to read in Engram, such as `<prefix>/roles/<role>/index`, or "none">
- **Seniority:** <agent · model · effort>

## Language

- **Artifacts** (code, docs, commits, PR): `<language.artifacts>`
- **App copy** (UI strings, manuals): `<language.app_copy>`, with these rules:
  - <each line of language.app_copy_rules>

## Task

- **PRD:** `<hub path>/<hub.prds_dir>/<slug>.md` — specs **<FR-n, SC-n>**. Read it; do not rely on this summary.
- **Target:** `<repo>` · paths `<…>`
- **Change:** <what must be true after this task>
- **Out of scope:** <what not to touch>

## Ownership and contract

- **You own:** <files or folders only you write>
- **You must not edit:** <files owned by other running tasks, shared registries>
- **Contract:** `<path to the contract or API schema>` — announce any change to it with `orca orchestration send`
  before you rely on it.

## Notes

- **Screen note:** <link, or "none: no screen changes">
- **Contract or design note:** <link, or "none">

## Acceptance

- **Observable result:** <what a person or a test sees>
- **Tests:** <the tests to add or update, as the repository's rules and the team conventions require>
- **Verification commands:** `<command>` → <expected result>
- **Freshness check:** `git fetch origin && git merge-base --is-ancestor origin/<main-line> HEAD` → exit 0 before
  you start; report it under Verification.

## For a non-Claude worker

<!--
Only for a unit routed to a provider of the stack's providers: list (agents/roles/tech-lead/SKILL.md, "Providers");
delete this section for a Claude worker. Fill every line with exact paths and exact commands, never a pattern such
as "any file in src/". The agent and its gotchas: docs/providers.md.
-->

This section lists everything you may do. Anything it does not list is forbidden, including reading other files
and running other commands, such as `env`, `ps` or a `find` over the home directory.

- **Files you may read:** `<exact paths>`
- **Files you may write:** `<exact paths, or "none" for an explore unit>`
- **Commands you may run:** `<each exact command>`, and the `orca orchestration` commands of your dispatch
  (heartbeat, `ask`, `worker_done`)
- **Staging and committing:** <"forbidden: leave the change in the worktree; the tech lead commits it after
  review" · or "allowed: `git add <exact paths>`, then one `git commit` with a Conventional Commit message">
- **Pushing and pull requests:** <"forbidden" · or "allowed: `git push origin <branch>`, no force; open the PR
  into `<target branch>`">
- **Memory:** read through the Engram MCP tool only, never the `engram` CLI: `mem_search` with
  `project: "<engram project>"`. You never save (`<team repo>/agents/README.md`, section "Memory").
- **Review:** Claude, the tech lead or a Claude reviewer, reviews your output before it is merged or used.

## Escalation

- A reversible decision: assume it, keep going, and report it.
- A product decision: `orca orchestration ask`, and continue with what does not depend on it.
- Blocked on the same thing for longer than the limit in `<team repo>/agents/README.md`, section "Template
  defaults", or the team conventions above: ask.

## Report

End with exactly one `worker_done` (`--outcome succeeded` or `--outcome failed`), a three-sentence body, and a
report at `--report-path` that follows `<team repo>/agents/templates/worker-report.md`.

<!-- Append <team repo>/agents/team-conventions.md below this line. -->
