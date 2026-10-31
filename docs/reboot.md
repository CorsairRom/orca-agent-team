# Reboot and reopen

What to do after the machine reboots, after Orca restarts, or when a coordinator chat stops reacting. The agents'
side is the RESUME path of the two after-start checklists: [Ideas'](../agents/templates/after-start-ideas.md) and
the [Tech-lead's](../agents/templates/after-start-tech-lead.md). The prompts that start it were written by the
installing chat to `<ideas dir>/resume-prompt.txt` and `<tech-lead dir>/resume-prompt.txt`
([placeholders](../agents/README.md#placeholders)).

Examples use the "acme" stack's default team: `~/.local/share/acme/ideas/` and `~/.local/share/acme/tech-lead/`.
With several [teams](../tools/README.md#teams), run the procedure once per team, with that team's folders under
`~/.local/share/acme/teams/<team id>/` and its worktrees `Ideas-<team id>` and `Tech-lead-<team id>`.

## What to do

| Situation | What to do |
| --- | --- |
| **Chat tab open**: the chat's tab is still there, but the chat does not react to mail | **HUMAN:** paste its resume prompt in that tab. Its checklist runs as a RESUME |
| **Chat closed**: its tab is gone, or the Chat UI's idle sweep stopped it ([gotchas](./gotchas.md#the-chat-ui-stops-an-idle-chat)); Orca and the monitors still run | **HUMAN:** reopen the chat in its own worktree from Orca's agent session history, then paste its resume prompt **in that same tab**: a new tab is a fresh session ([gotchas](./gotchas.md#the-first-prompt-of-a-resumed-chat-goes-in-the-same-tab)). The Tech-lead's checklist restarts the monitors anyway; that is harmless |
| **History refused**: the resumed chat refuses its long history `(unverified)` | **HUMAN:** start a fresh chat in the same worktree on purpose, and paste its resume prompt, adding that the history was refused. The fresh chat reads its checklist, `mem_context` and, for the Tech-lead, its inventory before anything else; the identity step of its checklist accepts it |
| **After a reboot**, or after Orca restarts | Follow [the procedure after a reboot](#after-a-reboot): both chats, Ideas first |

## After a reboot

### What a reboot loses

- Every chat's Claude process. A reopened chat stays idle until it gets a prompt `(unverified)`.
- The two monitor tmux sessions.
- Everything under `/tmp`. Nothing of this setup lives there.

What survives: the worktrees, the transcripts under `~/.claude/projects/`, the local-share tree with the run-id
files, the resume prompts and the briefs, the Engram memory, and the Runs. Whether a Run stays usable after a full
reboot is `(unverified)`: step 2 of each checklist checks it with `orca orchestration run-current` and creates a
new one only when the old one is unusable.

### The procedure

Steps marked **HUMAN** need the human in the Orca UI.

1. **HUMAN — start Orca** and check its three settings are unchanged: Chat UI on, "Agent sleep" off, "Agent
   Dashboard" on.
2. **HUMAN — reopen the Ideas chat** in the hub's Ideas worktree, from Orca's agent session history, so it resumes
   the same Claude session. Then paste the content of `~/.local/share/acme/ideas/resume-prompt.txt` **in that same
   tab**.
3. **Ideas runs its checklist as a RESUME:**
   - verifies it is its own session;
   - checks its Run, keeps it when it is the one in its run-id file, and otherwise creates a new one and writes its
     id to the run-id file;
   - reads its mailbox;
   - wakes the Tech-lead with a `[From Ideas] Ideas is back` message to the Tech-lead's Run that carries a token,
     `PONG-<n>` with a new `<n>` each time.
4. **HUMAN — reopen the Tech-lead chat** in the Tech-lead worktree the same way, if it is not among the open tabs.
   Ideas' message prompts it ([gotchas](./gotchas.md#orca-prompts-an-idle-chat-when-its-run-gets-mail)); whether
   that prompt reaches a chat reopened after a reboot is `(unverified)`. **When the token does not come back** to
   Ideas within a few minutes, the human pastes `~/.local/share/acme/tech-lead/resume-prompt.txt` in the
   Tech-lead's tab.
5. **The Tech-lead runs its checklist as a RESUME:**
   - verifies its identity and checks its Run, as Ideas did; the monitors read the run-id file on every send, so a
     new Run needs no restart;
   - reads its mailbox;
   - restarts the PR monitor and the permission watch from its own chat, as
     [`tools/README.md`](../tools/README.md#start) describes; expected: `tmux ls` lists both, and an alive check
     with the Tech-lead's own sender arrives in its mailbox;
   - reconciles its inventory with what is alive (below);
   - echoes Ideas' token back in a `[Tech-lead] ready` message to Ideas, with its Run id and anything lost.
6. **Ideas reports to the product owner:** the Runs in use, whether the token came back, and anything lost.

### Reconcile what is alive

The Tech-lead compares its inventory (by default the Engram topic `<inventory topic>`, where it
records every worktree, worker, tmux session and path it opens) with what is running:

```bash
. ~/.local/share/acme/stack.env
tmux ls
orca worktree list --json
orca orchestration worker-list --run "$(cat "$TECH_LEAD_RUN_ID_FILE")" --json
bash -c '. ~/.local/share/acme/stack.env; for ((i = 0; i < REPO_COUNT; i++)); do p="REPO_${i}_PATH"; git -C "${!p}" worktree list; done'
```

The last line needs bash, so it runs as `bash -c '...'` whatever the chat's shell is.

Also `ls` every path the inventory records. Everything recorded but not alive is reported to Ideas: dead workers,
missing worktrees, files lost from `/tmp`.

A supervised worker may survive an Orca restart `(unverified)`. Before relaunching one, read the mailbox and
`orca orchestration worker-show --dispatch <dispatch-id> --json`, and relaunch only when the old dispatch is
confirmed dead (no messages, no live process). Relaunch on the same worktree, either as a retry of the same task:

```bash
orca orchestration worker-start --task <task-id> --retry-of <dispatch-id> --worktree path:<absolute worktree path> \
  --agent claude --model <model> --effort <effort> --json
```

(`--retry-of` does not inherit placement, so repeat `--worktree` and `--agent`; `orca orchestration worker-start
--help`), or as a new task with `--spec` on the same `--worktree path:<absolute worktree path>`, without `--name`,
`--repo` or `--base-branch`.
