# Tech lead: after-start checklist

<!--
The tech lead runs this first: once on its first start, and again after every reopen, reboot or move to a new
surface. Values in <...> come from config/stack.yaml (see the placeholders table in agents/README.md). The reasons
behind each step: agents/README.md (The Run mailboxes), docs/reboot.md and docs/gotchas.md.
-->

Ideas is reached only through its Run mailbox, never by typing into its terminal or chat.

## Run it in this order

1. **Identity.** For a reopen or a move only. **First start: no prior session; skip to step 2.**

   Confirm this is the tech lead's own session, not a fresh one opened in the wrong tab:
   - `pwd` is the tech lead's hub worktree;
   - the shell has `ORCA_AGENT_SESSION_ID` set and no `ORCA_TERMINAL_HANDLE`
     (`env | grep -E '^ORCA_(AGENT_SESSION_ID|TERMINAL_HANDLE)='` prints only the first) `(unverified on 1.4.245)`;
   - the newest transcript, `ls -t ~/.claude/projects/<encoded path>/*.jsonl | head -1`, is the session you expect
     and grows with this turn (`<encoded path>` is the worktree's absolute path with every `/` and `.` replaced by
     `-`);
   - you can answer a question only the real session can, such as the last feature you worked on. Exception: when
     the product owner started a fresh chat on purpose because a long history was refused, read `mem_context` and
     the inventory (project `<engram project>`) instead.

   If any check fails, stop and tell the product owner, through Ideas, that the prompt went to the wrong tab.

2. **Run.** Check for a usable Run first:

   ```bash
   orca orchestration run-current --json | jq '.result.run'
   ```

   - It shows the Run whose id is in `<tech-lead run-id file>`: keep it.
   - It is `null`, or the Run is fenced or bound elsewhere: create one and store its id, only the id, on one line.
     Do this only with no live or pending dispatches on the old Run
     (`orca orchestration worker-list --run <old run id> --json`); otherwise finish or release them first.

     ```bash
     mkdir -p <tech-lead dir>/briefs <tech-lead dir>/timing
     orca orchestration run-create --objective "<stack.name> tech lead" --json
     orca orchestration run-current --json | jq -r '.result.run.id' > <tech-lead run-id file>
     cat <tech-lead run-id file>
     ```

     Expected: the file holds one Run id and nothing else. `(unverified on 1.4.245)`: the `.id` field under
     `.result.run`; `.result.run` itself is verified. In a chat, `run-create` binds no terminal, so the Run's
     coordinator handle is `null`; that is expected.

3. **Arm the mailbox wait** with Bash `run_in_background: true` and a Bash `timeout` of `1860000`, above
   `--timeout-ms`; never a detached `&`:

   ```bash
   orca orchestration check --run "$(cat <tech-lead run-id file>)" --wait --timeout-ms 1800000 --json
   ```

   On every wake: read the whole Delivery, heartbeats included, act on every message, then acknowledge and re-arm in
   one command, also with `run_in_background: true` and the same timeout:

   ```bash
   orca orchestration check --run "$(cat <tech-lead run-id file>)" --ack <delivery-id> --wait --timeout-ms 1800000 --json
   ```

   `<delivery-id>` is `.result.deliveryId` of the wait's output; a `--peek` read shows none. When the wait times out
   with nothing, re-arm without `--ack`.

4. **Start the monitors.** Load the config and start the PR monitor and the worker watch in the mode
   `orca.notify_mode` names, as [`tools/README.md`](../../tools/README.md) describes; stop any copy already running
   first. Then send the alive check the tools README names.

   Expected: `tmux ls` lists both monitor sessions, `<id>-pr-monitor` and `<id>-worker-watch`, and the alive check
   arrives in your mailbox. Their messages carry the source in the subject (`[PR monitor] ...`,
   `[Worker watch] ...`); Orca may show another sender, so trust the subject.

5. **Reconcile the inventory.** **First start: nothing to reconcile; skip to step 6.** Compare the Engram inventory
   `<prefix>/agents/tech-lead-inventory` (project `<engram project>`) with what is alive:

   ```bash
   tmux ls
   docker ps
   for r in <path of every repo in repos[]>; do git -C "$r" worktree list; done
   orca worktree list --json
   orca orchestration worker-list --run "$(cat <tech-lead run-id file>)" --json
   ```

   Also `ls` every path the inventory records. Note everything recorded that is not alive: dead workers, missing
   worktrees, local stacks not restarted, files that were under `/tmp`. Before relaunching a worker, check the
   mailbox and `orca orchestration worker-show --dispatch <dispatch-id> --json`, and relaunch only when the old
   dispatch is confirmed dead ([`docs/reboot.md`](../../docs/reboot.md)).

6. **Tell Ideas** through its Run. Write the body to a file in `<tech-lead dir>/briefs/` first, with:
   - **first start:** this is the first handshake; no token. Say you are up, your Run id file, and how to reach you;
   - **reopen, reboot or move:** the token from Ideas' wake message, echoed back exactly (`PONG-<n>`), if Ideas sent
     one, and what step 5 found lost, or "nothing lost".

   Then:

   ```bash
   orca orchestration send --to "run:$(cat <ideas run-id file>)" --type status \
     --subject "[Tech-lead] ready" --body "$(cat <file>)"
   ```

   Expected: the CLI confirms the send. On a first start, Ideas' answer arrives in your mailbox: the round trip is
   proven.

7. **Memory.** Update the Engram inventory `<prefix>/agents/tech-lead-inventory` (project `<engram project>`): your
   surface, your Run id and objective, the monitors and their mode, any retired Run, and what step 5 found lost.

## Standing rules

- After every wake: read the whole Delivery, act, acknowledge, re-arm in the background. Never end a turn without an
  armed wait. Orca's nudge is the fallback, not the rule: on a nudge with no wait running, read with
  `orca orchestration check --run <own run id> --json`, acknowledge, and re-arm.
- Reach Ideas only with `orca orchestration send --to "run:$(cat <ideas run-id file>)"`, subject prefix
  `[Tech-lead]`, body from a file. Never `orca terminal send` to another agent.
- Workers run under your Run with `orca orchestration worker-start ... --worktree new-child`; their mail arrives in
  the same mailbox. After `worker_done` a follow-up needs a new `worker-start --worktree path:<absolute path>`.
- A worker's scratch under `~/.config/orca/chat-scratch/` can hold sensitive exports; delete it after use.
- If a long history is refused on resume, start a fresh chat in the same worktree, then read this file,
  `mem_context` and the inventory before anything else.
