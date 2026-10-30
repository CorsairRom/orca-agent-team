# Test plan — <feature>

<!--
Written by the tech lead for the product owner after the reviewer and QA pass, and sent through Ideas.
Not a full test flow: only the steps where an agent decided something on its own, taken from the Assumptions of
every worker report, plus anything the reviewer or QA could not verify. Short: aim for 3 to 8 steps.
-->

- **Branches to test:** `<repo>`: `<target branch>` · **PRD:** `<hub path>/<hub.prds_dir>/<slug>.md`
- **Checked by agents:** <reviewer verdict · QA report>

| # | Step | Expected result | Why it needs you |
| --- | --- | --- | --- |
| 1 | <exact action, with screen or endpoint and data> | <what must appear> | Assumption A1 of `<role>`: <what was guessed> |
| 2 | ... | ... | ... |

## Not covered by any agent

<What nobody could verify and why: missing data, behaviour only a deployed environment shows, credentials.>

## After the merge

Check again in each environment before production, with its real data:

- <the one or two steps most sensitive to real data>
