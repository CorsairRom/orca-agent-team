# Known gotchas

Behaviour of Orca and Claude Code that this setup depends on, or works around. Each entry states the mechanism, the
source, and what to do. The entries hold for the minimum versions in the [README](../README.md#prerequisites);
re-check them after an upgrade. A point no `--help` text, `man` page or the Orca orchestration skill
(`orca skills get orchestration --full`) confirms is marked `(unverified)`.

## Mailbox and Runs

### Orca prompts an idle chat when its Run gets mail

When mail arrives in a Run, Orca injects a prompt into the idle chat bound to that Run. An idle chat with no
background command wakes on it; the chat needs no process of its own to wake up. Since Orca 1.4.248 a Chat UI chat
gets each message whole as its own prompt, marked read once the chat accepts it, so a later `check` does not return
it; a terminal agent, or a message too large for a chat message, still gets a prompt that names a `check` command
(`orca skills get orchestration --full`, "When Orca wakes you"). Whether the prompt also reaches a chat that the
Chat UI's idle sweep has closed is `(unverified)`.

**What to do:** follow [the mailbox rule](../agents/README.md#the-mailbox-rule): act on a message the prompt holds,
and run `check` only when the prompt names it.

### A plain check marks its batch handled

On Orca 1.4.246 a plain `check` returns the Run's oldest unread batch whole, never filtered by type, and marks it
handled: the result is `{"ok":true,"result":{"messages":[…]}}` with no `deliveryId`, and a second `check` returns
the next batch, or `"messages":[]` when none is left. A batch that is read but not acted on is not returned again.
`--peek` returns only unread messages without marking them. `--ack` is for a batch from an older Orca that does not
mark it (`orca orchestration check --help`); on such a version the same batch comes back on every `check` until it
is acknowledged with `--ack <deliveryId>` `(unverified)`.

**What to do:** act on every message of each batch as soon as it is read, and repeat `check` until `messages` is
empty, as [the mailbox rule](../agents/README.md#the-mailbox-rule) says.

### A Run is bound to the session that created it

A Run is bound to one coordinator session at a time: `run-create` creates a Run and binds it to the calling session,
and `run-current` shows the Run bound to the calling coordinator (`orca orchestration run-create --help`,
`run-current --help`). Observed on Orca 1.4.258:

- another session's `check --run <run_id>` is refused with `consumer_fenced` ("This caller is not bound to Run…");
- any session that is not a worker can take the Run over with `orca orchestration run-use --id <run_id>` ("Resume
  coordinating a Run"; a worker "cannot bind its own or ancestor Run", `run-use --help`). The Run's coordinator
  moves to the caller and its `consumer_generation` goes up; the previous coordinator's `run-current` returns
  `null`, its `check` is refused the same way, and it can take the Run back with `run-use` in turn;
- `orca orchestration inbox --terminal run:<run_id>` reads a Run's coordinator mail from any session, and
  `inbox --run <run_id>` also the mail to its workers (Orca 1.4.261 and later, observed on 1.4.280).

Whether a session that is not bound can still dispatch under the Run is `(unverified)`. A subagent's shell inherits
its parent's identity, so a subagent that runs `run-create` creates a Run of its parent `(unverified)`.

**What to do:** each coordinator creates its own Run from its own chat, in the first turn of its after-start
checklist, and writes the id to its run-id file. On a RESUME, a chat whose `run-current` shows no Run or another
one takes back the Run of its run-id file with `run-use --id` before it creates a new one, so the workers and peers
still mailing that Run keep reaching it. Run `run-use` only on the chat's own Run: it fences the session that held
it. The chat that installs the team creates no Run for them.

### Long background commands end with the Bash tool's limit

Claude Code's Bash tool stops a background command at its time limit, and the Chat UI's idle sweep ends every
process of the chat `(unverified)`. A chat that relies on a background command to stay alive, or to wake it later,
loses it without notice.

**What to do:** keep long-lived processes out of the chats. The monitors run in tmux sessions; the mailbox needs no
background command (see the first entry).

### Workers may start their own workers

Up to Orca 1.4.250 a worker could not start its own worker (nesting depth 1). Since 1.4.251 workers may, up to a
nested depth of 4 by default, and profiles set to 1 move to 4 on upgrade (stablyai/orca PR #38348, "Let workers
start their own workers by default (nested worker depth 4)").

**What to do:** nothing changes for the team. The Tech-lead is still not a worker of Ideas: both are top-level
coordinators with their own Runs, and they talk Run to Run. A worker starts no worker of its own: its brief lists
the only `orca orchestration` commands it may run.

### A tmux session sends under the identity it was started with

`orca orchestration send` takes its sender from the `ORCA_*` variables of its environment. A process in a new tmux
session starts from the server's global environment, which tmux copies from whoever started the server: another
chat, or no Orca process at all (`man tmux`, "GLOBAL AND SESSION ENVIRONMENT"). Observed on Orca 1.4.258:

- a session started with a chat's `ORCA_*` variables, through `tmux new-session -e`, sends as that chat:
  `orca_session_id:<the chat's ORCA_AGENT_SESSION_ID>`;
- a session started without them, on a tmux server another Orca terminal started, sends as that terminal: its
  `ORCA_TERMINAL_HANDLE`;
- with no `ORCA_*` variable at all, `send` is refused with `no_active_sender_terminal`: "Could not determine the
  calling terminal for this orchestration command. Pass --from with your own terminal's handle — another pane's
  handle would act on its mailbox — or run the command inside a live Orca terminal with ORCA_TERMINAL_HANDLE set."

**What to do:** the Tech-lead, a long-lived chat, starts the monitors and passes every `ORCA_*` variable of its own
environment with `tmux new-session -e` ([start lines](../tools/README.md#start)); the alive check's sender must be
the Tech-lead's ([Check the sender](../tools/README.md#check-the-sender)). Identify the source of a message by its
subject prefix: `[PR monitor]`, `[Worker watch]`, `[Bootstrap]`.

### A worker sends only within its coordinator's Run

A dispatched worker's `send --to run:<another run>` is refused with `dispatch_run_mismatch`: a Dispatch belongs to
one Run `(unverified)`.

**What to do:** messages between Ideas and the Tech-lead go chat to chat, through their Runs, never through a
worker.

### A finished worker takes a follow-up through send

Since Orca 1.4.246, `send --to dispatch:<id>` reaches a worker in any state: "a finished or closed one gets it as a
follow-up Task and reports with `worker_done`. The receipt says which" (`orca skills get orchestration --full`).
Orca reopens the worker in its worktree with its saved conversation, or starts the same agent fresh with the
earlier task and report as context (PR #36533). A finished worker on a paired server still refuses `send`.

Observed on Orca 1.4.258: the full receipt (`send ... --json --full`) holds `"delivery":"follow_up"` when the
worker was still live, or `"delivery":"reopened"` when it was already released, with `"followUpOf":"<old dispatch
id>"` and a new `taskId` and `dispatchId`. Later mail to the worker goes to the new dispatch id. A reopened Claude
worker resumed the same session on the same model and sent `worker_done` again.

Observed on Orca 1.4.280: the reopened worker must report on the new dispatch. A `worker_done` that names the old
one is refused with `dispatch_inactive` ("Dispatch <old id> ... is already completed. Your open Dispatch is <new
id>"), and nothing is sent (PR #49221). Orca also reopens a finished chat worker whose tab was closed (PR #47914).
A follow-up dispatch stores no start options: `worker-start --retry-of <follow-up dispatch id>` without `--agent`
is refused with `agent_unconfigured`.

**What to do:** send a follow-up to the worker that did the unit, and from then on use the new `dispatchId` of the
receipt for it; to retry a follow-up dispatch, pass `--agent` (and `--model`, `--effort`). When `send` is refused, or the follow-up needs
another agent or model, start a new `orca orchestration worker-start --worktree path:<absolute path> ...` on the
same worktree, without `--name`, `--repo` or `--base-branch`, which Orca refuses for an existing worktree
(`orca orchestration worker-start --help`).

## Chats and their settings

### Agent sleep must stay off

Orca's "Agent sleep" setting stops idle agents. Ideas and the Tech-lead are idle most of the time, waiting for mail.
The Orca 1.4.278 notes say a slept agent now looks idle and wakes in place when it is messaged (#44113); that is
`(unverified)` here, so the setting stays off.

**What to do:** keep "Agent sleep" off in the Orca settings (`orca.agent_sleep: false` in the config).

### The Chat UI stops an idle chat

Separately from "Agent sleep", Orca stops a chat's Claude process after it has been idle for a while. Since Orca
1.4.249 a chat setting decides when idle chat agents stop: "Choose **Never** if you want idle chat agents to remain
running" (release notes of 1.4.249). Anything running inside the chat's process ends with it. The chat's transcript,
its Run and its run-id file survive `(unverified)`.

**What to do:** set idle chat agents to stop **Never** ([Orca settings](./setup-guide.md#orca-settings)), and keep
nothing long-lived inside a chat. When a chat does not react to mail, the human sends its resume prompt in its
existing tab ([reboot](./reboot.md#what-to-do)).

### A chat relaunches with its saved effort

Orca saves the options of each chat. After a message is sent with an effort picked in the chat, Orca stores that
effort and passes it as `--effort` on every relaunch `(unverified)`. The effort precedence in Claude Code is
`(unverified)`: `CLAUDE_CODE_EFFORT_LEVEL` > an in-session `/effort` or `/model` pick > the `--effort` flag >
`~/.claude/settings.json` (`modelSettings.<model>.effortLevel`, then `effortLevel`) > the model's default.

**What to do:** set the effort at launch (`orca agent launch --model <id> --effort <level>`), and after a relaunch
read the process's real flags instead of trusting the label (Linux only, it reads `/proc`):

```bash
for p in $(pgrep -f claude); do readlink /proc/$p/cwd; tr '\0' ' ' < /proc/$p/cmdline | grep -oE -- '--(effort|model) [^ ]+'; done
```

Orca's own record (`worker-show --json`) is not proof of the process arguments.

### The chat picker cannot set the effort of a raw model id

The chat picker builds its models and efforts from Claude Code's model list, which names some models by an alias.
A chat on a model the picker knows only by its raw id gets no extended efforts, and `/effort <level>` is rejected
as not available for the chat session `(unverified)`.

**What to do:** pass the effort at launch with `--effort`, as above.

### The first prompt of a resumed chat goes in the same tab

A chat resumed from Orca's agent session history continues its Claude session only in that tab, and a prompt sent
to a new tab starts a fresh session `(unverified)`. A fresh session passes every functional check of a checklist, a
correct reply to a ping included.

**What to do:** send the resume prompt in the resumed tab, then verify identity, as step 1 of each after-start
checklist does: `pwd` is the agent's worktree, the newest transcript under `~/.claude/projects/<encoded worktree
path>/` grows with this turn, and the chat answers a question only the real session can answer. A very long
history may be refused on resume `(unverified)`; then follow the "History refused" row of the
[reboot table](./reboot.md#what-to-do).

### Typing into another agent overwrites the human's input

`orca terminal send` types into the target's input box (`orca terminal send --help`: "Send input to a live
terminal"), over whatever the human is typing there `(unverified)`.

**What to do:** coordinators and workers talk only through Run mailboxes.

### Orca passes its default args to every worker

Orca passes an agent's default args, its setting `agentDefaultArgs.<agent>`, on the command line of every worker of
that agent. Observed on Orca 1.4.258 with `--dangerously-skip-permissions` in the `claude` entry: Claude workers
never prompted, a write into `.git/` and a `touch` outside the worktree both ran, and no `approval` escalation
reached the coordinator. Whether that value is Orca's default or a user's choice is not known.

**What to do:** HUMAN: before a feature, check the value of `agentDefaultArgs.claude` in Orca's settings (where the
settings screen shows it is `(unverified)`). While it holds `--dangerously-skip-permissions`, no prompt stops a
Claude worker and none reaches the Tech-lead: the brief is its only limit, so write its ownership lines exactly
([brief template](../agents/templates/brief.md)).

## Shell and commands

### Shell expansion inside messages

`$(...)` and backticks inside a double-quoted `--body "..."` are run by the shell before Orca sees them, so a message
that quotes a command runs it, or arrives mangled.

**What to do:** write the body to a file first, in the sender's durable folder, and pass it as
`--body "$(cat <file>)"`. The substitution's output is not expanded again.

### `/tmp` is cleared on reboot

A file under `/tmp` is gone after a reboot; a worker whose brief was there receives only its bare path as a spec.

**What to do:** briefs, messages, reports and PR bodies live in the durable folders under
`<ideas dir>` and `<tech-lead dir>`, under `~/.local/share/<stack.id>/`.

### A worker that ends between two ticks is not watched

The [worker watch](../tools/README.md) ticks only the
workers alive at a tick (every 20 s by default). A worker that finishes inside one interval has no tick line, and
that is expected: its `worker_done`, or Orca's own `escalation` when it stopped without one, reaches the Tech-lead.
The watch no longer looks for permission prompts either: Orca escalates a prompt only a person can allow with an
`approval` ([Tech-lead, Run](../agents/roles/tech-lead/SKILL.md#run)).

### Engram may create small projects named after worktrees

An Engram setup that registers sessions by working directory may create 0-observation projects named after the
worktrees (`ideas`, `tech-lead`, a worker's worktree name). They are harmless.

**What to do:** nothing, or remove one with `engram delete project <name> --hard` after `engram projects list` shows
it holds 0 observations.

### Auto-mode permission checks block some command shapes

In Claude Code's auto mode, a permission check may stop a command that edits files in place or builds paths from a
command substitution, and an unattended agent then waits on a prompt nobody sees.

**What to do:** prefer the editor tool over `sed -i` and command substitutions in shell commands; auto-mode
permission checks may block them. A command that is denied or not approved is skipped and reported, never retried
in another shape.

### The Bash tool may run zsh

The Bash tool runs the user's login shell, which may be zsh. Bash-only syntax (indirect expansion `${!v}`, arrays,
`[[ ]]`) then fails with errors such as `bad substitution`.

**What to do:** write it inside `bash -c '...'`.

### `orca worktree rm` keeps the branch

Since Orca 1.4.246 `orca worktree rm` keeps the worktree's local branch, even with `--force`; `--force` forces the
worktree removal, not a branch deletion. `--delete-branch` attempts a safe deletion, including a branch that
predated the worktree, and keeps any branch whose changes Orca cannot prove are merged (`orca worktree rm --help`).
Remote branches stay on GitHub.

**What to do:** pass `--delete-branch` when the local branch should go with the worktree.

### Work-unit PRs may skip the repository's CI

Some repositories run their CI only on PRs into their main branch. With the default
[delivery model](./delivery-model.md), a feature's first CI run is then its integration PR.

**What to do:** when that CI run fails, the Tech-lead dispatches a fix unit into the integration branch.

## Other providers

Workers on agents other than Claude Code ([providers](./providers.md)). These entries hold on Orca 1.4.245,
Antigravity `agy` 1.4.2 and OpenCode 2.2.2, except where an entry names a later version; re-check them after an
upgrade of any of the three.

### Every worker inherits Orca's environment

A worker's process starts from the environment Orca was started with. A credential exported in a shell profile
reaches every agent and, through it, its model provider: an agent that runs `env` sends every value to the
provider. Some agents persist terminal environments to disk `(unverified)`.

**What to do:** keep credentials out of the global environment: in each tool's own auth store, in a 0600 file a
config references, or in a secret store ([credentials](./setup-guide.md#credentials)). Never export a
`GITHUB_TOKEN` or a `<PROVIDER>_API_KEY` in a shell profile.

### Antigravity chats run on agy

Since Orca 1.4.278 every Antigravity chat runs the `agy` CLI as `agy acp`, the user's own `agy` or Orca's copy
where there is none; Orca's separate Antigravity runtime and its own Google sign-in are gone (stablyai/orca PR
#48305). Orca's Sign in runs `agy acp --login`, so it signs `agy` itself in. The saved sign-in method picks the
home: a Google account uses `agy`'s own home and login, `~/.gemini`; a Gemini API key, Gemini Enterprise or gcloud
runs `agy` on a home Orca owns (`--gemini-dir`). Since 1.4.252 an Antigravity worker that runs `agy` in a terminal
fails at once with `Agent startup blocked: agent-sign-in-prompt` when `agy` is signed out (PR #38901).

Observed on Orca 1.4.280 with a Google account: a `worker-start --agent antigravity` worker ran
`agy acp --dangerously-skip-permissions` with the user's `HOME` and no `--gemini-dir`.

**What to do:** sign in once in Orca before the first Antigravity chat, a HUMAN step
([Antigravity setup](./providers.md#antigravity-setup)). A worker that fails with `agent-sign-in-prompt` needs
`agy` itself signed in on the machine.

### Antigravity reads MCP servers from agy's home

With a Google-account sign-in, an Antigravity worker reads MCP servers from `~/.gemini/config/mcp_config.json`, the
file `agy mcp add` writes (observed on Orca 1.4.280 and `agy` 1.5.18: its log names `~/.gemini/antigravity-cli` as
its data directory, `agy` ignores `GEMINI_HOME` and follows `HOME`). Before Orca 1.4.278 Orca's own runtime read
`<orca config>/antigravity-chat/config/mcp_config.json`; nothing reads that file now. Which file `agy` reads on a
home Orca owns (API key, Enterprise, gcloud) is `(unverified)`. A running session loads a changed file only after a
restart.

**What to do:** add the Engram server with `agy mcp add`, with the absolute path of `engram`, check it with
`agy mcp list`, then restart the session ([Antigravity setup](./providers.md#antigravity-setup)).

### Mail reaches a busy Antigravity worker only after its turn

Since Orca 1.4.268 mail to a busy Antigravity chat is held until its turn ends, while Claude gets it mid-turn
(stablyai/orca PR #45370, release notes). A correction sent to an Antigravity worker that is still working waits.

**What to do:** expect the delay; to stop a wrong Antigravity turn at once, stop the worker and retry it.

### Antigravity model ids carry the effort

An Antigravity model id ends with its effort, such as `gemini-3.8-flash-low`, `-medium` or `-high`. There is no
plain id, and `worker-start` takes no `--effort` for it.

**What to do:** pass the full id with `--model` ([start line](./providers.md#start-an-antigravity-worker)).

### Antigravity has full access by default

Orca's permission setting for Antigravity defaults to full access: nothing stops a write or a command. Under a
loose brief the model reads unrelated files and runs exploratory commands such as `env`, `ps` and `find`.

**What to do:** a brief for it lists the exact files and commands allowed and forbids everything else
([brief template](../agents/templates/brief.md)); it never takes a high-risk unit
([providers](./providers.md#when-the-team-uses-them)).

### Orca cannot pass a model to OpenCode v2

`worker-start --agent opencode2 --model <id>` is refused with `invalid_argument`: "Agent opencode2 does not support
launch-time model selection. Omit --model…". `--effort` is not supported either.

The agent id `opencode` takes a model: "OpenCode model selection requires an existing worktree, a verified
execution-host CLI, and an available model; effort is unsupported" (`orca orchestration worker-start --help`). On
Orca 1.4.258, `worker-start --agent opencode --model <id> --worktree path:<existing worktree>` was accepted and ran
`opencode acp` on that model, for the session and every message, and left OpenCode's saved model list unchanged.
That run used OpenCode 2.3.0, on which `opencode` and `opencode2` ran the same binary; the rest of this section was
checked on 2.2.2.

**What to do:** create the worktree first with `orca worktree create ... --setup skip --json`, then start the
worker with `--worktree path:<path> --agent opencode2` and no `--model`
([OpenCode start line](./providers.md#start-an-opencode-worker)). To set the model at launch instead, start it on
the same worktree with `--agent opencode --model <id>`.

### OpenCode ignores a default agent that is not primary

OpenCode uses `default_agent` only for an agent with `mode: primary` that is not hidden. A hidden agent or a
subagent is ignored, and OpenCode falls back to `build` without a word.

**What to do:** define the primary agent `team-worker` with its prompt and permissions and set it as
`default_agent` ([OpenCode setup](./providers.md#opencode-setup)). It also becomes your own OpenCode default.

### OpenCode starts on the most recent model

The OpenCode TUI starts on the most recent model, from its state file `model.json` (the `recent` list), not on the
agent's `model`. Whether an `opencode2` worker does too is `(unverified)`: in the check on Orca 1.4.258 with
OpenCode 2.3.0, the agent's model and the most recent one were the same. A worker started with
`--agent opencode --model <id>` runs on `<id>` ([above](#orca-cannot-pass-a-model-to-opencode-v2)).

**What to do:** HUMAN: open OpenCode and pick the intended model once, or start the worker with
`--agent opencode --model <id>`.

### OpenCode has no model fallback

When a free tier runs out, the session stops with `provider.free-limit` ("Free usage limit reached. ... or switch
models."). Nothing switches the model, and the session stops.

**What to do:** the Tech-lead reads the worker with `orca orchestration worker-read --dispatch <dispatch-id>
--source auto`, switches the `team-worker` model and dispatches again on the same worktree
([OpenCode limits](./providers.md#opencode-limits)).

### OpenCode's last matching permission rule wins

OpenCode applies the last rule that matches a command, in config order. An `ask` rule written before
`"git push *": "allow"` never applies.

**What to do:** write the `ask` rules for `git push --force*`, `git push * --force*`, `git push -f*`,
`git push * -f*` and `git push *+*` after the `allow` rule, and keep `git rebase *` and `git reset --hard *` on
`ask`. They do not catch combined short flags such as `-uf`, `git -C <dir> push --force` or `git -c ... push`
([OpenCode setup](./providers.md#opencode-setup)).

### `opencode mcp list` may show no servers

`opencode mcp list` may list no MCP servers while `opencode debug config` resolves them.

**What to do:** trust `opencode debug config`, and run `opencode reload` after every config edit.
