# PRD — <feature in one line>

<!--
Written by Ideas into the hub (<hub.prds_dir>/<slug>.md, wherever the hub keeps PRDs), in language.artifacts,
once the idea is refined. Short and dense. No implementation detail: say what must be true, not how to build it.
A bug uses the "Bug" section instead of the requirements' stories.
-->

- **Type:** feature | improvement | bug | research | question
- **Repositories:** <names from repos[] this touches>
- **Requested by:** <the product owner, or the user group it comes from>
- **Date:** YYYY-MM-DD

## Problem

What happens today, who suffers it and what it costs. Evidence with links.

## Outcome

What will be true when this is done, in one paragraph.

## Requirements

Stable IDs; never renumber. Quote the product owner's or their users' exact words where they exist.

- **FR-1** <requirement>
- **FR-2** <requirement>

## Acceptance criteria

Each one checkable by a test or by a person in the product.

- **SC-1** (FR-1) Given <state>, when <action>, then <observable result>.
- **SC-2** (FR-2) ...

## Bug

Only for a bug.

- **Actual:** what happens, with the steps to reproduce it.
- **Expected:** what should happen.
- **Must not change:** behaviour around it that stays as it is.

## Out of scope

What this explicitly does not include.

## Open questions

`[NEEDS CLARIFICATION]` items the tech lead must resolve or send back before planning. A PRD with open questions
about product behaviour is not ready.

## Decision log

Appended, never rewritten. Decisions of the product owner are quoted verbatim.

- YYYY-MM-DD — <decision> (<the product owner | the tech lead>)
