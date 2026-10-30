# Ideas: after-start checklist

<!--
Ideas runs this first: once on its first start, and again after every reopen, reboot or move to a new surface.
Values in <...> come from config/stack.yaml (see the placeholders table in agents/README.md). The reasons behind
each step: agents/README.md (The Run mailboxes), docs/reboot.md and docs/gotchas.md.
-->

Run every step in order, then report to the product owner in `language.owner_conversation`.

1. **Identity.** For a reopen or a move only. **First start: no prior session; skip to step 2.**

   Confirm this is Ideas' own session, not a fresh one opened in the wrong tab:
   - `pwd` is Ideas' hub worktree;
   - the shell has `ORCA_AGENT_SESSION_ID` set and no `ORCA_TERMINAL_HANDLE`
     (`env | grep -E '^ORCA_(AGENT_SESSION_ID|TERMINAL_HANDLE)='` prints only the first) `(unverified on 1.4.245)`;
   - the newest transcript, `ls -t ~/.claude/projects/<encoded path>/*.jsonl | head -1`, is the session you expect
     and grows with this turn (`<encoded path>` is the worktree's absolute path with every `/` and `.` replaced by
     `-`);
   - you remember the requests worked on before. Exception: when the product owner started a fresh chat on purpose
     because a long history was refused, read `mem_context` (project `<engram project>`) instead.

   If any check fails, stop and tell the product owner the prompt went to the wrong tab.

2. **Run.** Check for a usable Run first:

   ```bash
   orca orchestration run-current --json | jq '.result.run'
   ```

   - It shows the Run whose id is in `<ideas run-id file>`: keep it.
   - It is `null`, or the Run is fenced or bound elsewhere (a Run created under a terminal or by another chat
     session cannot be consumed from this chat): create one and store its id, only the id, on one line:

     ```bash
     mkdir -p <ideas dir>/briefs
     orca orchestration run-create --objective "<stack.name> Ideas inbox" --json
     orca orchestration run-current --json | jq -r '.result.run.id' > <ideas run-id file>
     cat <ideas run-id file>
     ```

     Expected: the file holds one Run id and nothing else. `(unverified on 1.4.245)`: the `.id` field under
     `.result.run`; `.result.run` itself is verified.

3. **Arm the mailbox wait** with Bash `run_in_background: true`, never a detached `&`:

   ```bash
   orca orchestration check --run "$(cat <ideas run-id file>)" --wait --timeout-ms 1800000 --json
   ```

   On every wake: read the whole Delivery, relay or act on every message, then acknowledge and re-arm in one
   command, also with `run_in_background: true`:

   ```bash
   orca orchestration check --run "$(cat <ideas run-id file>)" --ack <delivery-id> --wait --timeout-ms 1800000 --json
   ```

   `<delivery-id>` is `.result.deliveryId` of the wait's output. When the wait times out with nothing, re-arm
   without `--ack`.

4. **Handshake.**
   - **First start:** do not write to the tech lead: it does not exist yet, or has no Run. Its first message to your
     Run is the handshake. When it arrives, answer it with the send below, subject
     `[From Ideas] handshake received`, and no token.
   - **Reopen, reboot or move:** when `<tech-lead run-id file>` exists, wake the tech lead. Write the body to a file
     in `<ideas dir>/briefs/` first: Ideas is back, its Run id, and a token for the tech lead to echo back,
     `PONG-<n>` with a new `<n>` each time. Then:

     ```bash
     orca orchestration send --to "run:$(cat <tech-lead run-id file>)" --type status \
       --subject "[From Ideas] Ideas is back" --body "$(cat <file>)"
     ```

     Expected: the CLI confirms the send, and the tech lead's reply carrying the same token arrives in your
     mailbox. If it does not, ask the product owner to prompt the tech-lead tab to run its checklist.

5. **Memory.** Save an Engram note under `<prefix>/agents/ideas-status` (project `<engram project>`): Ideas' surface,
   its Run id file, and anything that failed.

6. **Report to the product owner:** what you checked, the Run in use, whether the handshake or the token came back,
   and anything that failed.

## Standing rules

- After every wake: read the whole Delivery, act, acknowledge, re-arm in the background. Never end a turn without an
  armed wait. On an Orca nudge with no wait running, read with `orca orchestration check --run <own run id> --json`,
  acknowledge, and re-arm.
- Reach the tech lead only with `orca orchestration send --to "run:$(cat <tech-lead run-id file>)"`, subject prefix
  `[From Ideas]` or `[From Ideas, product owner's decision]`, body from a file. Never `orca terminal send` to
  another agent.
