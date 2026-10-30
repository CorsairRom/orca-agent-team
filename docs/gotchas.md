# Known gotchas

Behaviour of Orca and Claude Code that this setup depends on, or works around. Each entry says what happens, why it
matters here, and what to do. They were observed on Orca 1.4.243 to 1.4.245 with Claude Code 2.1; re-check them
after an upgrade. A point that was not reproduced is marked `(unverified)`.

## Mailbox and Runs

### Orca nudges an idle chat when its Run gets mail

An idle chat that is bound to a Run receives a new prompt from Orca when mail arrives in that Run, of the form
"You have N orchestration message(s). Run `orca orchestration check --run <run-id>`". This was observed repeatedly
on coordinator chats, in chat and terminal mode, and after a reopen.

**What to do:** the nudge is the fallback, not the rule. Each chat keeps one mailbox wait armed in the background,
`orca orchestration check --run <own run id> --wait --timeout-ms 1800000 --json`, with Bash `run_in_background` and
a Bash timeout above `--timeout-ms`, and acknowledges and re-arms it after every delivery
([the Run mailboxes](../agents/README.md#the-run-mailboxes)). The nudge covers a wait that ended or was killed. On a
nudge, the chat reads the whole Delivery with `orca orchestration check --run <own run id> --json`, acts on every
message, and acknowledges the batch with `orca orchestration check --run <own run id> --ack <deliveryId> --json`.
Repeat the plain check with the previous `--ack` until `deliveryId` is `null`, then re-arm the wait. A Run replays
the same Delivery until it is acknowledged, so an unacknowledged batch hides newer mail.

### Long background commands are killed by the harness

Claude Code's Bash tool stops a background command at its time limit (30 minutes by default). A chat that relies on
a background command to stay alive, or to wake it later, loses it silently.

**What to do:** keep long-lived processes out of the chats. The monitors run in tmux sessions. The mailbox wait is
the one background command a chat keeps: give its Bash call a timeout above its `--timeout-ms`, re-arm it after
every delivery, and count on Orca's nudge when it is gone anyway.

### A mailbox wait outlives its Bash timeout

`orca orchestration check --wait --timeout-ms <n>` blocks for up to `<n>` milliseconds. If the Bash call that runs
it has a shorter timeout, Bash kills it first, and the wait's result, including the `deliveryId`, is lost.

**What to do:** give every wait's Bash call a timeout above `--timeout-ms`. The armed background wait uses
`--timeout-ms 1800000` with Bash `run_in_background` and a timeout of `1860000` (a background Bash call accepts up to
7200000 ms). A foreground wait, for example while proving the round trip, uses `--timeout-ms 540000` with a Bash
timeout of `600000`: in the foreground, Claude Code's Bash timeout is at most 600000 ms.

### A Run belongs to the session that created it

A Run is bound to the identity that created it. A Run created in a chat is bound to that chat session: another
session reading its mailbox gets `This caller is not bound to Run ...`. A Run created under a terminal identity
cannot be consumed from a chat, so a resumed chat cannot use a Run created under another surface. A subagent's shell
inherits its parent's identity, so a subagent that runs `run-create` creates a Run coordinated by its parent.

**What to do:** each coordinator creates its own Run from its own chat, and stores the id in its Run id file.
Moving a coordinator between a terminal and a chat needs a new Run: create it from the new surface, write its id,
and tell the other coordinator. Move only when no dispatch is live or pending in the old Run
(`orca orchestration worker-list --run <old run id> --json`), because workers keep mailing the Run they were
started in.

### Nesting depth is 1

A worker cannot start its own worker. The attempt is refused with
`nested_worker_depth_exceeded: Sub-worker dispatch is not permitted at depth 2 (max 1)`.

**What to do:** this is why the Tech-lead is not a worker of Ideas. Both are top-level coordinators with their own
Runs, and they talk Run to Run.

### Unacknowledged mail and senders without an Orca identity

- `--peek` and `--all` show rows but return no `deliveryId`; take it from a plain `check`.
- `--types` is only the wake condition of `--wait`; a Delivery is never filtered by type.
- A message sent from a shell with no Orca identity, such as a monitor in tmux, may show another terminal as its
  sender. The subject prefix (`[PR monitor]`, `[Worker watch]`, `[Bootstrap]`) is what identifies the source.

### A settled worker cannot be reused

After `worker_done` the dispatch is complete: `send --to dispatch:<settled id>` is refused with `dispatch_inactive`.
A follow-up needs a new `orca orchestration worker-start --worktree path:<absolute path> ...` on the same worktree,
without `--name`, `--repo` or `--base-branch`, which Orca refuses for an existing worktree.

## Chats and their settings

### Agent sleep must stay off

Orca's experimental «Agent sleep» stops idle agents, and a slept coordinator is not woken by mail. Ideas and the
Tech-lead are idle most of the time, waiting for mail, so with «Agent sleep» on a Run can stall silently. This is
documented upstream and was not reproduced here `(unverified)`.

**What to do:** keep «Agent sleep» off in the Orca settings (`orca.agent_sleep: false` in the config).

### The Chat UI stops an idle chat after 30 minutes

Separately from «Agent sleep», Orca stops a chat's Claude process after 30 minutes idle. It cannot be configured.
Anything running inside the chat's process, such as a background command, ends with it.

**What to do:** nothing long-lived inside a chat (see above). The chat's state is its transcript, its Run and its
Run id file, which survive the sweep. Whether a nudge always brings a swept chat back is `(unverified)`; when a chat
does not react to mail, the human sends it a prompt in its existing tab.

### A chat relaunches with its saved effort

Orca saves the options of each chat. Once a message is sent after using the chat's model or effort picker, Orca
stores that effort in its session record and passes it as `--effort` on every relaunch. The `--effort` flag beats
`~/.claude/settings.json`. The observed precedence in Claude Code is: `CLAUDE_CODE_EFFORT_LEVEL` > an in-session
`/effort` or `/model` pick > the `--effort` flag > `~/.claude/settings.json` (`modelSettings.<model>.effortLevel`,
then `effortLevel`) > the model's default. A chat adopted from a terminal starts with no saved effort.

**What to do:** set the effort you want at launch (`orca agent launch --model <id> --effort <level>`), and after a
relaunch read the real flags of the process instead of trusting the label:

```bash
for p in $(pgrep -f claude); do readlink /proc/$p/cwd; tr '\0' ' ' < /proc/$p/cmdline | grep -oE -- '--(effort|model) [^ ]+'; done
```

This reads `/proc`, so it works on Linux only. Orca's own record (`worker-show --json`) is not proof of the process
arguments. Workers get an explicit `--effort` from `worker-start`, and it reached the process on the workers checked.

### The chat picker cannot set the effort of a raw model id

The chat picker builds its models and efforts from Claude Code's model list, which names some models by an alias.
A chat on a model the picker knows only by its raw id gets no extended efforts, and `/effort <level>` is rejected
with "`<value>` is not an available `<option>` for this chat session." Observed on Orca 1.4.243.

**What to do:** pass the effort at launch with `--effort`, as above, instead of picking it in the chat.

### The first prompt of a resumed chat goes in the same tab

When a session is resumed in a chat (for example with «Continue in Chat UI» on a terminal tab, or from Orca's agent
session history), the first prompt must be sent in that same tab. A prompt sent to a new tab starts a fresh Claude
session, and a fresh session passes every functional check of a checklist, a correct reply to a ping included.

**What to do:** send the prompt in the resumed tab, then verify identity: `pwd` is the agent's worktree; the shell
has `ORCA_AGENT_SESSION_ID` and no `ORCA_TERMINAL_HANDLE`; the newest transcript under `~/.claude/projects/<encoded
worktree path>/` grows with this turn; and the chat answers a question only the real session can answer. A very
long history may be refused on resume; then start a fresh chat on purpose and have it read its checklist and
`mem_context` first.

### Typing into another agent overwrites the human's input

`orca terminal send` types into the target's input box, over whatever the human is typing there.

**What to do:** coordinators and workers talk only through Run mailboxes.

## Shell and commands

### Shell expansion inside messages

`$(...)` and backticks inside a double-quoted `--body "..."` are run by the shell before Orca sees them, so a message
that quotes a command runs it, or arrives mangled.

**What to do:** write the body to a file first, in the sender's durable folder, and pass it as
`--body "$(cat <file>)"`. The substitution's output is not expanded again.

### `/tmp` is cleared on reboot

A brief left under `/tmp` is gone after a reboot, and a worker may then receive only its bare path as a spec.

**What to do:** briefs, messages, reports and PR bodies live in the durable folders under
`~/.local/share/<stack.id>-ideas/` and `~/.local/share/<stack.id>-tech-lead/`.

### Auto-mode permission prompts on two command shapes

In Claude Code's auto mode, two shapes trigger a safety prompt that blocks an unattended agent:

- `sed -i` in the same Bash call as a shell array built from a command substitution of `git status`;
- `rm` on a path built from a command substitution, such as `$(mktemp)`.

**What to do:** make the edit with the Edit tool and explicit file paths; pass PR bodies with
`gh pr create --body-file <fixed path>`, and leave temp-file cleanup to the Tech-lead. A command that is denied or
not approved is skipped and reported, never retried in another shape and never waited on.

### `orca worktree rm` also deletes the branch

`orca worktree rm` tries to delete the worktree's checked-out local branch, with or without `--force`; `--force`
forces the worktree removal, not the branch deletion. Orca keeps a branch that predated the worktree and any branch
it cannot prove is merged (`orca worktree rm --help`). Remote branches stay on GitHub.

### Work-unit PRs may skip the repository's CI

Some repositories run their CI only on PRs into their main branch. Then a feature's first CI run is its integration
PR. When it fails, the Tech-lead dispatches a fix unit into the integration branch
([delivery model](./delivery-model.md)).
