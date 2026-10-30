# Known gotchas

Behaviour of Orca and Claude Code that this setup depends on, or works around. Each entry states the mechanism, the
source, and what to do. The entries hold for the minimum versions in the [README](../README.md#prerequisites);
re-check them after an upgrade. A point no `--help` text, `man` page or the Orca orchestration skill
(`orca skills get orchestration --full`) confirms is marked `(unverified)`.

## Mailbox and Runs

### Orca prompts an idle chat when its Run gets mail

When mail arrives in a Run, Orca injects a prompt into the idle chat bound to that Run. An idle chat with no
background command wakes on it; the chat needs no process of its own to wake up. Whether the prompt also reaches a
chat that the Chat UI's idle sweep has closed is `(unverified)`.

**What to do:** follow [the mailbox rule](../agents/README.md#the-mailbox-rule), which quotes the prompt.

### A Run replays a Delivery until it is acknowledged

A plain `check` returns the Run's oldest unacknowledged batch, the Delivery, whole: it is never filtered by type.
The same Delivery comes back on every `check` until it is acknowledged with `--ack <deliveryId>`, so an
unacknowledged batch hides newer mail. `--peek` and `--all` show rows but return no `deliveryId`; take it from a
plain `check` (`orca orchestration check --help`).

**What to do:** process every message, then acknowledge, as [the mailbox rule](../agents/README.md#the-mailbox-rule)
says.

### A Run is bound to the session that created it

A Run is bound to the session that created it; another session cannot read its mailbox or dispatch under it.
`run-create` creates and binds a Run, and `run-current` shows the Run bound to the calling coordinator
(`orca orchestration run-create --help`, `run-current --help`); that another session is refused is `(unverified)`. A
subagent's shell inherits its parent's identity, so a subagent that runs `run-create` creates a Run of its parent
`(unverified)`.

**What to do:** each coordinator creates its own Run from its own chat, in the first turn of its after-start
checklist, and writes the id to its run-id file. The chat that installs the team creates no Run for them.

### Long background commands end with the Bash tool's limit

Claude Code's Bash tool stops a background command at its time limit, and the Chat UI's idle sweep ends every
process of the chat `(unverified)`. A chat that relies on a background command to stay alive, or to wake it later,
loses it without notice.

**What to do:** keep long-lived processes out of the chats. The monitors run in tmux sessions; the mailbox needs no
background command (see the first entry).

### Nesting depth is 1

A worker cannot start its own worker. The attempt is refused with `nested_worker_depth_exceeded`, and creating
another Run does not reset the depth (the Orca orchestration skill). The full refusal text is `(unverified)`.

**What to do:** this is why the Tech-lead is not a worker of Ideas. Both are top-level coordinators with their own
Runs, and they talk Run to Run.

### A tmux session sends under the identity it was started with

`orca orchestration send` takes its sender from the `ORCA_*` variables of its environment `(unverified)`. A
process in a new tmux session starts from the server's global environment, which tmux copies from whoever started
the server: another chat, or no Orca process at all (`man tmux`, "GLOBAL AND SESSION ENVIRONMENT"). A monitor in
such a session sends as that other chat, or is refused with `no_active_sender_terminal` `(unverified)`.

**What to do:** the Tech-lead, a long-lived chat, starts the monitors and passes every `ORCA_*` variable of its own
environment with `tmux new-session -e` ([start lines](../tools/README.md#start)); the alive check's sender must be
the Tech-lead's ([Check the sender](../tools/README.md#check-the-sender)). Identify the source of a message by its
subject prefix: `[PR monitor]`, `[Worker watch]`, `[Bootstrap]`.

### A worker sends only within its coordinator's Run

A dispatched worker's `send --to run:<another run>` is refused with `dispatch_run_mismatch`: a Dispatch belongs to
one Run `(unverified)`.

**What to do:** messages between Ideas and the Tech-lead go chat to chat, through their Runs, never through a
worker.

### A settled worker cannot be reused

After `worker_done` the dispatch is complete: `send --to dispatch:<settled id>` is refused with `dispatch_inactive`
`(unverified)`.

**What to do:** a follow-up needs a new `orca orchestration worker-start --worktree path:<absolute path> ...` on the
same worktree, without `--name`, `--repo` or `--base-branch`, which Orca refuses for an existing worktree
(`orca orchestration worker-start --help`).

## Chats and their settings

### Agent sleep must stay off

Orca's "Agent sleep" setting stops idle agents, and mail does not wake a slept agent `(unverified)`. Ideas and the
Tech-lead are idle most of the time, waiting for mail.

**What to do:** keep "Agent sleep" off in the Orca settings (`orca.agent_sleep: false` in the config).

### The Chat UI stops an idle chat

Separately from "Agent sleep", Orca stops a chat's Claude process after it has been idle for a while; the
30-minute limit, and that it is not configurable, are `(unverified)`. Anything running inside the chat's process
ends with it. The chat's transcript, its Run and its run-id file survive `(unverified)`.

**What to do:** nothing long-lived inside a chat. When a chat does not react to mail, the human sends its resume
prompt in its existing tab ([reboot](./reboot.md#what-to-do)).

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

## Shell and commands

### Shell expansion inside messages

`$(...)` and backticks inside a double-quoted `--body "..."` are run by the shell before Orca sees them, so a message
that quotes a command runs it, or arrives mangled.

**What to do:** write the body to a file first, in the sender's durable folder, and pass it as
`--body "$(cat <file>)"`. The substitution's output is not expanded again.

### `/tmp` is cleared on reboot

A file under `/tmp` is gone after a reboot; a worker whose brief was there receives only its bare path as a spec.

**What to do:** briefs, messages, reports and PR bodies live in the durable folders under
`~/.local/share/<stack.id>/ideas/` and `~/.local/share/<stack.id>/tech-lead/`.

### A worker that ends between two ticks is not watched

The [worker watch](../tools/README.md) ticks only the
workers alive at a tick (every 20 s by default). That is enough: a worker parked on a prompt stays alive, so a
later tick sees it. A worker that finishes inside one interval has no tick line, and that is expected. On the
minimum Orca version, `worker-show` gives no `agentWait` field for a running worker, so the `worker-read` fallback
is the path that runs; whether `agentWait` appears for a parked worker is `(unverified)`.

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

### `orca worktree rm` also deletes the branch

`orca worktree rm` tries to delete the worktree's checked-out local branch, with or without `--force`; `--force`
forces the worktree removal, not the branch deletion. Orca keeps a branch that predated the worktree and any branch
it cannot prove is merged (`orca worktree rm --help`). Remote branches stay on GitHub.

### Work-unit PRs may skip the repository's CI

Some repositories run their CI only on PRs into their main branch. With the default
[delivery model](./delivery-model.md), a feature's first CI run is then its integration PR.

**What to do:** when that CI run fails, the Tech-lead dispatches a fix unit into the integration branch.
