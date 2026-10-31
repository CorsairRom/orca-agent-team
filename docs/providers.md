# Workers on other providers

By default every worker is a Claude Code session. Orca can also start a supervised worker on another agent, such as
Antigravity or OpenCode v2, under the same Run, with the same `worker_done`, `ask` and heartbeats. This page says
when the team uses one, how each agent is set up, and how a new provider is accepted.

Everything here is checked on Orca 1.4.245, Antigravity `agy` 1.4.2 and OpenCode 2.2.2. A point that is not is
marked `(unverified)`. The gotchas behind each step are in [gotchas](./gotchas.md#other-providers).

## When the team uses them

The stack lists its other providers in the optional `providers:` section of `config/stack.yaml`, documented in
[`config/stack.example.yaml`](../config/stack.example.yaml). The chat that writes the env file turns it into the
`PROVIDER_*` keys ([Writing the env file](../tools/README.md#writing-the-env-file)). With no `providers:` section,
or an empty one, every worker is Claude, with the model of its seniority.

Each entry names the Orca agent id, the model id passed at launch (empty when Orca cannot pass one) and the task
kinds it takes:

| Task kind | What it is |
| --- | --- |
| `explore` | Read-only exploration and mapping |
| `docs-draft` | A documentation draft that the Tech-lead or a Claude writer finalizes |
| `mechanical` | A small change that follows a pattern: a rename, a lint or format fix, a test that copies an existing one |

The example in `config/stack.example.yaml` is an illustration: Antigravity for `explore` and `docs-draft`,
OpenCode for `mechanical`, Claude for everything else. Each stack sets its own. These rules are fixed, whatever
the config says:

- Claude takes every kind, and every unit no provider lists.
- A unit with a high-risk item never goes to a non-Claude worker.
- Claude reviews every non-Claude worker's output before it counts.
- A provider is used only after [its smoke test](#accepting-a-new-provider-the-smoke-test) passes.

A brief for a non-Claude worker lists the exact files and commands it may use, forbids everything else, and says
whether it may commit ([brief template](../agents/templates/brief.md)). The routing is the Tech-lead's
([Tech-lead card](../agents/roles/tech-lead/SKILL.md)).

## Antigravity

Orca agent id `antigravity`. Orca runs its own Antigravity chat runtime for it, separate from the `agy` CLI you
may use yourself.

### Antigravity setup

1. **HUMAN:** in Orca, sign in to Antigravity with a Google account. Orca's runtime has its own sign-in; an `agy`
   login on the machine does not carry over.
2. **HUMAN:** check Orca's permission setting for Antigravity. Its default is full access: nothing stops a write
   or a command. The brief is then the only limit, so it lists the exact files and commands allowed.
3. Give the runtime the Engram MCP server. Orca runs it with `GEMINI_HOME=<orca config>/antigravity-chat`, and it
   reads MCP servers from `<orca config>/antigravity-chat/config/mcp_config.json`, not from `~/.gemini`, where
   `agy mcp add` writes. Write that file with the absolute path of `engram` (`command -v engram`):

   ```json
   {
     "mcpServers": {
       "engram": { "command": "<absolute path to engram>", "args": ["mcp", "--tools=agent"] }
     }
   }
   ```

   A running Antigravity session loads it only after a restart.

### Start an Antigravity worker

The model id carries the effort as a suffix: `gemini-3.8-flash-low`, `gemini-3.8-flash-medium` or
`gemini-3.8-flash-high`. There is no plain id, and no `--effort`.

```bash
orca orchestration worker-start \
  --spec "Your brief is the file <absolute brief path>. Read it whole first and follow it exactly." \
  --task-title "<title>" --worktree new-child --name <worktree name> --repo path:<repo path> --base-branch <ref> \
  --agent antigravity --model gemini-3.8-flash-medium --json
```

### Antigravity limits

- Under a loose brief the model reads unrelated files and runs exploratory commands, such as `env`, `ps` and
  `find`. With the default full access nothing stops them, and `env` prints every variable of its environment to
  the model provider ([gotchas](./gotchas.md#every-worker-inherits-orcas-environment)).
- Only the effort levels above exist; there is no plain model id.

## OpenCode v2

Orca agent id `opencode2`. OpenCode reads its own config (`~/.config/opencode/opencode.json` by default `(unverified)`),
and Orca passes neither a model nor an effort to it.

### OpenCode setup

1. **A primary worker agent as the default.** OpenCode starts on `default_agent` only when that agent has
   `mode: primary` and is not hidden; otherwise it falls back to `build` without a word. Define one primary agent,
   `team-worker`, with a worker prompt and its permissions, and make it the default. This also changes your own
   default agent when you run OpenCode by hand. Scoping it to Orca's sessions through Orca's per-agent
   environment, `OPENCODE_CONFIG_CONTENT`, is `(unverified)`.

   The shape below is `(unverified)` beyond `mode: primary`, `default_agent`, `{file:<path>}` and the rule order.

   ```json
   {
     "$schema": "https://opencode.ai/config.json",
     "default_agent": "team-worker",
     "agent": {
       "team-worker": {
         "mode": "primary",
         "description": "Supervised Orca worker",
         "model": "<provider>/<model>",
         "prompt": "{file:./prompts/team-worker.md}",
         "permission": {
           "edit": "allow",
           "bash": {
             "*": "allow",
             "git push *": "allow",
             "git push --force*": "ask",
             "git push * --force*": "ask",
             "git push -f*": "ask",
             "git push * -f*": "ask",
             "git push *+*": "ask",
             "git rebase *": "ask",
             "git reset --hard *": "ask"
           }
         }
       }
     },
     "mcp": {
       "engram": { "type": "local", "command": ["<absolute path to engram>", "mcp", "--tools=agent"], "enabled": true }
     }
   }
   ```

   The rule for `"*"` is the stack's choice; a rule set to `ask` parks the worker on a prompt, which the
   [worker watch](../tools/README.md) reports `(unverified)`.

2. **The permission order.** The last matching rule wins, in config order. So the `ask` rules for a force push
   come after `"git push *": "allow"`, and `git rebase *` and `git reset --hard *` stay `ask`. These patterns do
   not cover combined short flags such as `-uf`, `git -C <dir> push --force` or `git -c ... push`.
3. **The worker prompt**, `~/.config/opencode/prompts/team-worker.md` `(unverified)`, at least:

   ```text
   You are a supervised worker started by Orca. Your brief is the file the task names: read it whole first and
   follow it exactly. Use only the files and commands it allows. Do not run git add, git commit or git push
   unless the brief allows it. Ask questions with orca orchestration ask. End with exactly one worker_done.
   ```

4. **HUMAN: pick the model once.** The TUI starts on the most recent model, from OpenCode's state file
   `model.json` (its `recent` list), not on the agent's `model`. Open OpenCode and pick the intended model once.
5. **Check the config.** `opencode debug config` shows the resolved config; trust it over `opencode mcp list`,
   which may show no servers when the config has them. After an edit, run `opencode reload`.

### Start an OpenCode worker

Orca refuses `--model` for `opencode2` ("does not support launch-time model selection"), and `--effort` is not
supported. So the worktree is created first, then the worker starts on it:

```bash
orca worktree create --repo path:<repo path> --name <worktree name> --base-branch <ref> --setup skip --json
orca orchestration worker-start \
  --spec "Your brief is the file <absolute brief path>. Read it whole first and follow it exactly." \
  --task-title "<title>" --worktree path:<worktree path> --agent opencode2 --json
```

Read `<worktree path>` from the `--json` output of `worktree create`. Run it from the Tech-lead's chat; that the
worktree then nests under the Tech-lead's is `(unverified)`.

### OpenCode limits

- **No automatic model fallback.** When a free tier runs out, the session stops with `provider.free-limit` ("Free
  usage limit reached. ... or switch models."), and the session stops there. The [worker
  watch](../tools/README.md#worker-watchsh-run_id-interval_seconds----once-run_id----help) reports the error to the
  Tech-lead, which can also see it with `orca orchestration worker-read --dispatch <dispatch-id> --source auto`,
  switches the `team-worker` model, and dispatches again on the same worktree.
- The model is the one the agent config and the most recent pick say, never one the Tech-lead passes.
- `git push` is allowed by the permissions; the prompt and the brief decide whether the worker uses it.

## Accepting a new provider: the smoke test

One dispatch shows that a provider can work as a team worker: it reads its card, reaches the shared memory through
MCP, writes a file, and reports through the Run. Run it once per provider and agent id, before the first real unit,
and again after an upgrade of Orca or of the agent.

1. Finish the provider's setup above, HUMAN steps included.
2. The Tech-lead writes the brief below to `<tech-lead dir>/briefs/smoke-<agent>.md`, with every placeholder filled.
3. The Tech-lead starts the worker on the hub, from `<hub main branch>`, with the provider's start line above and
   the spec `Your brief is the file <absolute brief path>. Read it whole first and follow it exactly.`
4. It waits for the result in its Run mailbox, by [the mailbox rule](../agents/README.md#the-mailbox-rule).

The brief to dispatch:

```markdown
# Brief — smoke test of <agent>

This is a smoke test. Do only the four steps below, in order. Do not read any other file and do not run any
other command. Do not commit, push or open a PR.

1. Send one heartbeat to the Tech-lead with the heartbeat command of your task preamble.
2. Read the first 30 lines of `<team repo>/agents/roles/dev-docs/SKILL.md`.
3. Call the Engram MCP tool `mem_context` once, with `project: "<engram project>"`. Use the MCP tool; never the
   `engram` command line.
4. Write `smoke.txt` at the root of your worktree:
   - first line: the first heading of the card you read;
   - then the result of the `mem_context` call, or its exact error;
   - then your agent id and your model id.

Then send exactly one `worker_done` with `--outcome succeeded`, or `--outcome failed` with the exact error, and a
three-sentence body.
```

The provider passes when all of these hold:

- a heartbeat and the `worker_done` arrive in the Tech-lead's Run;
- the worker watch ticks the dispatch: `worker-watch.ticks` in `<team dir>/monitors/` has a line for it
  ([logs and state](../tools/README.md#logs-and-state));
- `smoke.txt` holds the card's heading, a `mem_context` result rather than an error, and the agent and model;
- `orca orchestration worker-read --dispatch <dispatch-id> --source auto` shows the MCP tool call, not an `engram`
  command.

Then add the provider to `providers:` and write the env file again. When it fails, keep it out of `providers:` and
keep the exact error. Either way, release the worker with `orca orchestration worker-release --dispatch
<dispatch-id>` and remove its worktree with `orca worktree rm`; `smoke.txt` is never committed.
