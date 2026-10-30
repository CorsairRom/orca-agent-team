# Tech-lead: after-start checklist

<!--
The Tech-lead runs this as the first turn of its chat: once on its FIRST START (the installing chat launches it with
this file), and again on every RESUME (after a reboot, an Orca restart or a reopen). The prompt that starts the turn
says which, and gives `<stack.id>` and `<team repo>`. The reasons behind each step: agents/README.md (The Run
mailboxes), docs/reboot.md and docs/gotchas.md.
-->

Ideas is reached only through its Run mailbox, never by typing into its chat.

Every command block starts by loading the stack's env file, written from `config/stack.yaml` as
[`tools/README.md`](../../tools/README.md#writing-the-env-file) describes: `. ~/.local/share/<stack.id>/stack.env`.
Shell variables do not survive between Bash calls, so load it in each block. It sets `$TECH_LEAD_DIR`
(`<tech-lead dir>`), `$TECH_LEAD_RUN_ID_FILE`, `$IDEAS_RUN_ID_FILE`, `$STACK_ID`, `$STACK_NAME`, `$TEAM_REPO`,
`$ENGRAM_PROJECT`, `$TOPIC_PREFIX` and the `REPO_<i>_*` keys ([placeholders](../README.md#placeholders)). No
command here reads `config/stack.yaml`.

## Run it in this order

1. **Identity.** RESUME only. **FIRST START: there is no prior session; skip to step 2.**

   Confirm this is the Tech-lead's own session, not a fresh one opened in the wrong tab:
   - `pwd` is the Tech-lead's hub worktree;
   - the newest transcript, `ls -t ~/.claude/projects/<encoded path>/*.jsonl | head -1`, is the session you expect
     and grows with this turn (`<encoded path>` is the worktree's absolute path with every `/` and `.` replaced by
     `-`);
   - you can answer a question only the real session can, such as the last feature you worked on. Exception: when
     the product owner started a fresh chat on purpose because a long history was refused
     ([reboot](../../docs/reboot.md#what-to-do)), read `mem_context` and the inventory (project `$ENGRAM_PROJECT`)
     instead.

   If any check fails, stop and tell the product owner, through Ideas, that the prompt went to the wrong tab.

2. **Run.** A Run is bound to the session that created it, so the Tech-lead creates its own, from this chat:

   ```bash
   . ~/.local/share/<stack.id>/stack.env
   orca orchestration run-current --json | jq '.result.run'
   cat "$TECH_LEAD_RUN_ID_FILE" 2>/dev/null
   ```

   - The Run shown is the one whose id is in the run-id file: keep it.
   - It is `null`, or another Run, or the command refuses this caller: create one and store its id, only the id, on
     one line. On a RESUME, first check the old Run for live or pending dispatches
     (`orca orchestration worker-list --run <old run id> --json`): their mail keeps going to the old Run, so list
     them in step 6.

     ```bash
     . ~/.local/share/<stack.id>/stack.env
     mkdir -p "$TECH_LEAD_DIR/briefs" "$TECH_LEAD_DIR/reports" "$TECH_LEAD_DIR/pr-bodies"
     orca orchestration run-create --objective "$STACK_NAME Tech-lead" --json
     orca orchestration run-current --json | jq -r '.result.run.id' > "$TECH_LEAD_RUN_ID_FILE"
     cat "$TECH_LEAD_RUN_ID_FILE"
     ```

     Expected: the file holds one Run id and nothing else. The `.result.run.id` path is `(unverified)`; `.result.run`
     is the key `run-current --json` returns. The monitors read the file on every send, so a new Run needs no restart.
3. **Mailbox.** Read the mailbox once now, by [the mailbox rule](../README.md#the-mailbox-rule). Messages with the
   subject prefix `[PR monitor]` or `[Worker watch]` may be there already; read and acknowledge them.

4. **Monitors.** FIRST START and RESUME. You start them, from this chat, so they send under your Orca identity;
   the installing chat does not. Stop any copy still running and start both, with the start lines of
   [`tools/README.md`](../../tools/README.md#start), which win over this summary. The block needs bash, so it runs
   as `bash -c '...'`:

   ```bash
   bash -c '
   . ~/.local/share/<stack.id>/stack.env
   orca_env=(); while IFS= read -r v; do orca_env+=(-e "$v"); done < <(env | grep "^ORCA_")
   tmux kill-session -t "$STACK_ID-pr-monitor" 2>/dev/null; tmux kill-session -t "$STACK_ID-worker-watch" 2>/dev/null
   tmux new-session -d -s "$STACK_ID-pr-monitor"   "${orca_env[@]}" "STACK_ENV_FILE=\"$STACK_ENV_FILE\" \"$TEAM_REPO/tools/pr-monitor.sh\""
   tmux new-session -d -s "$STACK_ID-worker-watch" "${orca_env[@]}" "STACK_ENV_FILE=\"$STACK_ENV_FILE\" \"$TEAM_REPO/tools/worker-watch.sh\""
   tmux ls
   '
   ```

   Then send the alive check from inside the PR monitor's session:

   ```bash
   . ~/.local/share/<stack.id>/stack.env
   tmux new-window -d -t "$STACK_ID-pr-monitor" "STACK_ENV_FILE=\"$STACK_ENV_FILE\" \"$TEAM_REPO/tools/pr-monitor.sh\" --notify 'alive check'"
   sleep 5; tail -n 1 "$MONITOR_DIR/monitor.log"
   ```

   Expected: `tmux ls` lists `<stack.id>-pr-monitor` and `<stack.id>-worker-watch`; the last line of `monitor.log`
   is the send receipt; `[PR monitor] alive check` arrives in your mailbox. After step 6, check its sender with
   [Check the sender](../../tools/README.md#check-the-sender): it must be the same as your `[Tech-lead] ready`.
   Another sender, or a refused send: run this step again from this chat.

5. **Reconcile the inventory.** RESUME only. Compare the Engram inventory (by default the topic
   `$TOPIC_PREFIX/agents/tech-lead-inventory`, project `$ENGRAM_PROJECT`) with what is alive:

   ```bash
   . ~/.local/share/<stack.id>/stack.env
   tmux ls
   orca worktree list --json
   orca orchestration worker-list --run "$(cat "$TECH_LEAD_RUN_ID_FILE")" --json
   bash -c '. ~/.local/share/<stack.id>/stack.env; for ((i = 0; i < REPO_COUNT; i++)); do p="REPO_${i}_PATH"; git -C "${!p}" worktree list; done'
   ```

   Also `ls` every path the inventory records. Note everything recorded that is not alive: dead workers, missing
   worktrees, files that were under `/tmp`. Before relaunching a worker, read the mailbox and
   `orca orchestration worker-show --dispatch <dispatch-id> --json`, and relaunch only when the old dispatch is
   confirmed dead ([`docs/reboot.md`](../../docs/reboot.md#reconcile-what-is-alive)).

6. **Tell Ideas** through its Run. Write the body to a file in `$TECH_LEAD_DIR/briefs/` first:
   - **FIRST START:** the handshake. Say you are up, your run-id file, and how to reach you; no token. End with
     Ideas' next step: `Next: run step 4 of your after-start checklist (answer this handshake).`
   - **RESUME:** the token from Ideas' wake message, echoed back exactly (`PONG-<n>`), if Ideas sent one, your Run
     id, any dispatch left on an old Run, and what step 5 found lost, or "nothing lost". End with
     `Next: run step 6 of your after-start checklist (report to the product owner).`

   ```bash
   . ~/.local/share/<stack.id>/stack.env
   orca orchestration send --to "run:$(cat "$IDEAS_RUN_ID_FILE")" --type status \
     --subject "[Tech-lead] ready" --body "$(cat <file>)" --json
   ```

   Expected: the CLI answers with a message id. On a FIRST START, end this turn; Orca prompts you when Ideas'
   answer arrives.

7. **Record the confirmation.** FIRST START only. When `[From Ideas] handshake received` arrives in your mailbox,
   write Ideas' Run id, only the id, to `$TECH_LEAD_DIR/handshake-ok.txt`, then acknowledge the Delivery:

   ```bash
   . ~/.local/share/<stack.id>/stack.env
   cat "$IDEAS_RUN_ID_FILE" > "$TECH_LEAD_DIR/handshake-ok.txt"
   ```

   The installing chat reads this file to prove the handshake went both ways.

8. **Memory.** Update the Engram inventory (by default `$TOPIC_PREFIX/agents/tech-lead-inventory`, project
   `$ENGRAM_PROJECT`, passed explicitly as the Engram rule below says; the topic is a default, change it freely): your Run id and objective, the two monitor
   sessions, any retired Run, and what step 5 found lost.

## Standing rules

- **Mailbox.** Read and acknowledge your mail by [the mailbox rule](../README.md#the-mailbox-rule); `<own run id>`
  is `$(cat "$TECH_LEAD_RUN_ID_FILE")`.
- Reach Ideas only with `orca orchestration send --to "run:$(cat "$IDEAS_RUN_ID_FILE")"`, subject prefix
  `[Tech-lead]`, body from a file. Never `orca terminal send` to another agent.
- Workers run under your Run with `orca orchestration worker-start ... --worktree new-child`; their mail arrives in
  the same mailbox. After `worker_done` a follow-up needs a new `worker-start --worktree path:<absolute path>`.
- Every brief carries the team's `conventions:`, the lines of `$CONVENTIONS_FILE`
  ([`tools/README.md`](../../tools/README.md#writing-the-env-file)); a new project has none.
- A `[Bootstrap]` message comes from the chat that installed the team; do what it asks.
- **Engram.** Every Engram call passes `project: "<value of $ENGRAM_PROJECT>"` explicitly; read the value once
  with `. ~/.local/share/<stack.id>/stack.env; echo "$ENGRAM_PROJECT"`. Never ask the product owner which project,
  and never pick one from `mem_current_project`: this rule wins over any general memory instruction. The installing
  chat created the project; if a call still answers `unknown_project`, run the project line of
  [bootstrap step 5](../../BOOTSTRAP_PROMPT.md#step-5-create-the-durable-folders-the-engram-project-and-the-two-hub-worktrees) once, retry, and report it ([memory](../README.md#memory)).
- If a long history is refused on resume, follow the "History refused" row of the
  [reboot table](../../docs/reboot.md#what-to-do).
