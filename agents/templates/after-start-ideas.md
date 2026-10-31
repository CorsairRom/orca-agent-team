# Ideas: after-start checklist

<!--
Ideas runs this as the first turn of its chat: once on its FIRST START (the installing chat launches it with this
file), and again on every RESUME (after a reboot, an Orca restart or a reopen). The prompt that starts the turn says
which, and gives `<stack.id>` and `<env file>`. The reasons behind each step: agents/README.md (The Run mailboxes), docs/reboot.md and
docs/gotchas.md.
-->

Run every step in order. Every command block starts by loading the stack's env file, written from
`config/stack.yaml` as [`tools/README.md`](../../tools/README.md#writing-the-env-file) describes:
`. <env file>`. `<env file>` is the env file the prompt that started this turn names; a prompt that names none means the default team's, `~/.local/share/<stack.id>/stack.env` ([teams](../../tools/README.md#teams)). Shell variables do not survive between Bash calls, so
load it in each block; no command here reads `config/stack.yaml`. It sets `$IDEAS_DIR` (`<ideas dir>`), `$IDEAS_RUN_ID_FILE`,
`$TECH_LEAD_RUN_ID_FILE`, `$STACK_NAME`, `$ENGRAM_PROJECT` and `$TOPIC_PREFIX`
([placeholders](../README.md#placeholders)). If the env file sets no `TEAM_DIR`, it predates [teams](../../tools/README.md#teams): write it again first, with an empty `<team id>`, by [Writing the env file](../../tools/README.md#writing-the-env-file).

1. **Identity.** RESUME only. **FIRST START: there is no prior session; skip to step 2.**

   Confirm this is Ideas' own session, not a fresh one opened in the wrong tab:
   - `pwd` is Ideas' hub worktree;
   - the newest transcript, `ls -t ~/.claude/projects/<encoded path>/*.jsonl | head -1`, is the session you expect
     and grows with this turn (`<encoded path>` is the worktree's absolute path with every `/` and `.` replaced by
     `-`);
   - you remember the requests worked on before. Exception: when the product owner started a fresh chat on purpose
     because a long history was refused ([reboot](../../docs/reboot.md#what-to-do)), read `mem_context` (project
     `$ENGRAM_PROJECT`) instead.

   If any check fails, stop and tell the product owner the prompt went to the wrong tab.

2. **Run.** A Run is bound to the session that created it, so Ideas creates its own, from this chat:

   ```bash
   . <env file>
   orca orchestration run-current --json | jq '.result.run'
   cat "$IDEAS_RUN_ID_FILE" 2>/dev/null
   ```

   - The Run shown is the one whose id is in the run-id file: keep it.
   - It is `null`, or another Run, or the command refuses this caller: create one and store its id, only the id, on
     one line:

     ```bash
     . <env file>
     mkdir -p "$IDEAS_DIR/briefs"
     orca orchestration run-create --objective "$STACK_NAME Ideas inbox${TEAM_ID:+ ($TEAM_ID)}" --json
     orca orchestration run-current --json | jq -r '.result.run.id' > "$IDEAS_RUN_ID_FILE"
     cat "$IDEAS_RUN_ID_FILE"
     ```

     Expected: the file holds one Run id and nothing else. The `.result.run.id` path is `(unverified)`; `.result.run`
     is the key `run-current --json` returns.

3. **Mailbox.** Read the mailbox once now, by [the mailbox rule](../README.md#the-mailbox-rule). On a FIRST START
   it is usually empty.

4. **Handshake.**
   - **FIRST START:** do not write to the Tech-lead. Its first message to your Run, subject `[Tech-lead] ready`, is
     the handshake. End this turn now; Orca prompts you when it arrives, and its body names your next step. Then
     answer it, with the body written to a file in `$IDEAS_DIR/briefs/` first: Ideas is up, its run-id file, and
     the Tech-lead's next step, the line `Next: run step 7 of your after-start checklist (record the
     confirmation).`

     ```bash
     . <env file>
     orca orchestration send --to "run:$(cat "$TECH_LEAD_RUN_ID_FILE")" --type status \
       --subject "[From Ideas] handshake received" --body "$(cat <file>)" --json
     ```

   - **RESUME:** when `$TECH_LEAD_RUN_ID_FILE` exists, wake the Tech-lead. Write the body to a file in
     `$IDEAS_DIR/briefs/` first: Ideas is back, its Run id, a token for the Tech-lead to echo back,
     `PONG-<n>` with a new `<n>` each time, and the line `Next: run your after-start checklist as a RESUME.`
     Then:

     ```bash
     . <env file>
     orca orchestration send --to "run:$(cat "$TECH_LEAD_RUN_ID_FILE")" --type status \
       --subject "[From Ideas] Ideas is back" --body "$(cat <file>)" --json
     ```

     Expected: the CLI answers with a message id, and the Tech-lead's `[Tech-lead] ready` reply with the same
     token arrives in your mailbox. If it does not within a few minutes, ask the product owner to send the
     Tech-lead's tab its resume prompt (`<tech-lead dir>/resume-prompt.txt`), in that same tab.

5. **Memory.** Save an Engram note under `$TOPIC_PREFIX/agents/ideas-status` (project `$ENGRAM_PROJECT`, passed
   explicitly as the Engram rule below says; the topic is a default, change it freely): Ideas' run-id file, the Run in use, and anything that failed.

6. **Report to the product owner,** in `language.owner_conversation`: what you checked, the Run in use, whether the
   handshake or the token came back, and anything that failed. On a FIRST START, report after the handshake.

## Standing rules

- **Mailbox.** Read and acknowledge your mail by [the mailbox rule](../README.md#the-mailbox-rule); `<own run id>`
  is `$(cat "$IDEAS_RUN_ID_FILE")`.
- Reach the Tech-lead only with `orca orchestration send --to "run:$(cat "$TECH_LEAD_RUN_ID_FILE")"`, subject
  prefix `[From Ideas]` or `[From Ideas, product owner's decision]`, body from a file. Never `orca terminal send` to
  another agent.
- A `[Bootstrap]` message comes from the chat that installed the team; do what it asks.
- **Engram.** Every Engram call passes `project: "<value of $ENGRAM_PROJECT>"` explicitly; read the value once
  with `. <env file>; echo "$ENGRAM_PROJECT"`. Never ask the product owner which project,
  and never pick one from `mem_current_project`: this rule wins over any general memory instruction. The installing
  chat created the project; if a call still answers `unknown_project`, run the project line of
  [bootstrap step 5](../../BOOTSTRAP_PROMPT.md#step-5-create-the-durable-folders-the-engram-project-and-the-two-hub-worktrees) once, retry, and report it ([memory](../README.md#memory)).
