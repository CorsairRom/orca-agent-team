# Brief — <task title>

<!--
Written by the tech lead for one Orca task, saved in <tech-lead dir>/briefs/<brief>.md (never under /tmp), and
passed to worker-start as: --spec "Your brief is the file <absolute path>. Read it whole first and follow it exactly."
It references the PRD; it never paraphrases it. The team conventions are appended at the end.
-->

## Precedence

This brief takes precedence over any global instruction you have loaded:

- Ask questions with `orca orchestration ask`, never with an interactive menu.
- Your base branch is `<integration-branch>`; your PR targets it. Never touch the main line.
- **Team conventions:** they are appended at the end of this brief. Apply them to everything you write.
- Tests: one end-to-end test per behaviour; a unit test only where this brief names one, or where the repository's
  own rules require it.
- The PR body follows the target repository's PR template, or, where it has none, the structure of its merged PRs
  (an assumption; report it).
- Do not open issues against any project. Do not save to Engram; report learnings in your report.
- Engram reads use `project: "<engram project>"`.
- **Fresh base (mandatory):** before you start, run `git fetch origin` and check your base holds the latest main
  line (`git merge-base --is-ancestor origin/<main-line> HEAD`). If it does not, do not start:
  `orca orchestration ask` the tech lead. Never rebase or update the integration branch yourself.
- **Base architecture (mandatory):** reuse the repository's existing infrastructure. Create no new shared layer,
  cross-domain module, parallel mechanism, library or pattern without a decision from the tech lead; the reviewer
  treats a violation as a blocker.

## Identity

- **Role card:** `<team repo>/agents/roles/<role>/SKILL.md` — read it first.
- **Role memory:** read `<prefix>/roles/<role>/index` in Engram, then the lessons it lists.
- **Seniority:** <agent · model · effort>

## Language

- **Artifacts** (code, docs, commits, PR): `<language.artifacts>`
- **App copy** (UI strings, manuals): `<language.app_copy>`, with these rules:
  - <each line of language.app_copy_rules>

## Task

- **PRD:** `<hub>/features/<slug>.md` — specs **<FR-n, SC-n>**. Read it; do not rely on this summary.
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
- **Tests:** <the end-to-end test to add or update; a named unit test only for a critical piece>
- **Verification commands:** `<command>` → <expected result>
- **Freshness check:** `git fetch origin && git merge-base --is-ancestor origin/<main-line> HEAD` → exit 0 before
  you start; report it under Verification.

## Escalation

- A reversible decision: assume it, keep going, and report it.
- A product decision: `orca orchestration ask`, and continue with what does not depend on it.
- Blocked for more than 15 minutes on the same thing: ask.

## Report

End with exactly one `worker_done` (`--outcome succeeded` or `--outcome failed`), a three-sentence body, and a
report at `--report-path` that follows `<team repo>/agents/templates/worker-report.md`.

<!-- Append <team repo>/agents/team-conventions.md below this line. -->
