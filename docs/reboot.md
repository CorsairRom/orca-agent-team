# Reboot and reopen

What to do after the machine reboots, after Orca restarts, or when a coordinator chat was closed and has to be
reopened. The two after-start checklists hold the agents' side:
[Ideas'](../agents/templates/after-start-ideas.md) and the
[Tech-lead's](../agents/templates/after-start-tech-lead.md). Their filled-in copies live in
`~/.local/share/<stack.id>-ideas/after-start.md` and `~/.local/share/<stack.id>-tech-lead/after-start.md`
([setup guide](./setup-guide.md#durable-folders)).

Examples use the «acme» stack: `~/.local/share/acme-ideas/` and `~/.local/share/acme-tech-lead/`.

## What a reboot loses

- Every chat's Claude process. A reopened chat stays idle until it gets a prompt or an Orca nudge.
- The two monitor tmux sessions.
- Everything under `/tmp`. Nothing of this setup should live there.
- Any background command a chat had started.

What survives: the worktrees, the transcripts under `~/.claude/projects/`, the durable folders with the Run id files
and the briefs, the Engram memory, and the Runs themselves. After a chat reopen, a Run created by the same chat
session stayed usable. Whether a Run stays usable after a full reboot is `(unverified)`: the checklists check it
before relying on it.

## The procedure

Steps marked **HUMAN** need the human in the Orca UI.

1. **HUMAN — start Orca** and check its settings are unchanged: Chat UI on, «Agent sleep» off, «Agent Dashboard» on.
2. **HUMAN — reopen the Ideas chat** in the hub's «Ideas» worktree, from Orca's agent session history, so it resumes
   the same Claude session. The exact UI step after a reboot is `(unverified)`. Then send it one message **in that
   same tab** (a new tab is a fresh session, see [gotchas](./gotchas.md#the-first-prompt-of-a-resumed-chat-goes-in-the-same-tab)):

   ```text
   Run your after-start checklist, ~/.local/share/acme-ideas/after-start.md, as a reopen.
   ```

3. **Ideas runs its checklist:**
   - verifies it is its own session (identity checks in the checklist);
   - checks its Run with `orca orchestration run-current --json`, keeps it when it is the one in its Run id file,
     and creates a new one only when the old one is gone, fenced or bound elsewhere, writing the new id to its Run
     id file;
   - wakes the Tech-lead with a `[From Ideas]` message to the Tech-lead's Run that carries a confirmation token,
     `PONG-<n>` with a new `<n>` each time.
4. **HUMAN — reopen the Tech-lead chat** in «Tech-lead» the same way, if it is not among the open tabs. No prompt is
   needed: a reopened chat has no armed wait yet, and Orca's fallback nudge to an idle chat bound to a Run
   ([gotchas](./gotchas.md#orca-nudges-an-idle-chat-when-its-run-gets-mail)) starts it on Ideas' wake message; its
   checklist then re-arms the wait.
   **When the token does not come back** to Ideas within a few minutes, the human sends the Tech-lead tab, in that
   same tab:

   ```text
   Run your after-start checklist, ~/.local/share/acme-tech-lead/after-start.md, as a reopen.
   ```

5. **The Tech-lead runs its checklist:**
   - verifies its identity and checks its Run, as Ideas did; a new Run means a new id in its Run id file, which the
     monitors read on every send, and a note to Ideas;
   - restarts the PR monitor and the permission watch in `run` mode, as [`tools/README.md`](../tools/README.md)
     describes; expected: `tmux ls` lists both, and an alive check arrives in its mailbox;
   - reconciles its inventory with what is alive (below);
   - echoes Ideas' token back in a `[Tech-lead]` message to Ideas, with its Run id and anything lost.
6. **Ideas reports to the product owner:** the Runs in use, whether the token came back, and anything lost.

### Reconcile what is alive

The Tech-lead compares its inventory (the Engram topic under `memory.topic_prefix` where it records every worktree,
worker, tmux session, container and data path it opens) with what is running:

```bash
tmux ls
orca worktree list --json
orca orchestration worker-list --run "$(cat ~/.local/share/acme-tech-lead/run-id.txt)" --json
for p in <every repository path of the config>; do git -C "$p" worktree list; done
```

Also `ls` every path the inventory records, and `docker ps` when the stack uses containers. Everything recorded but
not alive is reported to Ideas: dead workers, missing worktrees, local stacks not restarted, files lost from `/tmp`.

A supervised worker can survive an Orca restart. Before relaunching one, check the mailbox and
`orca orchestration worker-show --dispatch <dispatch-id> --json`, and relaunch only when the old dispatch is
confirmed dead (no messages, no terminal). Relaunch on the same worktree, either as a retry of the same task:

```bash
orca orchestration worker-start --task <task-id> --retry-of <dispatch-id> --worktree path:<absolute worktree path> \
  --agent claude --model <model> --effort <effort> --json
```

(`--retry-of` needs `--task` and does not inherit placement, so repeat `--worktree` and `--agent`), or as a new task
with `--spec` on the same `--worktree path:<absolute worktree path>`, without `--name`, `--repo` or
`--base-branch`.

## Reopening one chat without a reboot

When only one chat was closed, or Orca's 30-minute idle sweep stopped it
([gotchas](./gotchas.md#the-chat-ui-stops-an-idle-chat-after-30-minutes)), the monitors are still running. Reopen
that chat in its own worktree and send it its checklist in the same tab, as in steps 2 or 4. The Tech-lead's
checklist restarts the monitors anyway; that is harmless.

## Moving a chat to a new surface

Moving a coordinator between an Orca terminal and a chat (for example with «Continue in Chat UI» on a terminal tab)
keeps its Claude session, but not its Run: a Run created under a terminal identity cannot be consumed from a chat
([gotchas](./gotchas.md#a-run-belongs-to-the-session-that-created-it)). Move only with no live or pending dispatches
(`orca orchestration worker-list --run <old run id> --json`); finish or release them first
(`orca orchestration worker-release --dispatch <dispatch-id>`). Then:

1. Quit Claude in the terminal, and choose «Continue in Chat UI» on the same tab.
2. Send the first prompt in that same tab, pointing to the agent's checklist.
3. Verify identity (the checklist's first step).
4. Create a new Run from the chat, write its id to the Run id file, and tell the other coordinator.

A very long history may be refused on resume. Then start a fresh chat in the same worktree on purpose, and have it
read its checklist, `mem_context` and, for the Tech-lead, its inventory before anything else.

A coordinator kept in a terminal restores its Run after a reboot with
`orca orchestration run-use --id <run id>`; until then `worker-start` fails with `consumer_fenced`.
