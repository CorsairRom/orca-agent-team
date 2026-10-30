# Worker report — <task title>

<!--
Every worker ends with exactly one worker_done: --outcome succeeded | failed, a three-sentence --body, and
--files-modified and --report-path when they apply. The report at --report-path follows this shape, in a durable
folder, never under /tmp.
-->

## Summary

Three sentences: what was done, what was verified, what is left.

## Specs covered

| Spec | Status | Evidence |
| --- | --- | --- |
| FR-1 / SC-1 | done · partial · not done | test name, command output, screenshot |

## Assumptions

Every decision taken without asking. These become the product owner's test plan, so each one says where to look.

| # | Assumption | Why | Where to check it |
| --- | --- | --- | --- |
| A1 | <what was assumed> | <what was missing> | <screen, endpoint or file:line> |

## Verification

- Freshness, before starting: `git fetch origin && git merge-base --is-ancestor origin/<main-line> HEAD`: <result>
- `<command>`: <observed result>

## Changes

- Branch and PR: `<branch>` → `<target branch>` (#<n>)
- Files: <list>

## Learnings

Facts the next instance of this role should know, each tied to evidence. The tech lead decides whether any becomes
a lesson.

## Deviations

Any point where the brief was not followed, and why. Include every case where a global instruction won over the
brief.
