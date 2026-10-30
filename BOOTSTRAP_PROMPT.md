# Bootstrap prompt: bring up the Ideas and Tech-lead chats in Orca

You are an AI running in an Orca chat (Claude Code) on a checkout of this repository. Execute this file end to end,
in order, against `config/stack.yaml`. At the end, the Ideas chat and the Tech-lead chat run in the hub repository,
each owns a Run, the two monitors run, and one message has gone Ideas → Tech-lead → Ideas.

## Rules while you execute

- Run every step's commands, compare the output with **Expected**, and only then go on. On a mismatch, stop and tell
  the human which step failed, the command, and its output. Do not improvise a different path.
- A step marked **HUMAN** needs the human in the Orca UI or at a login prompt. Tell them exactly what to do, then
  stop and wait for their answer before you go on.
- Run the commands from this repository's root. Never run them from inside the hub's «Ideas» or «Tech-lead»
  worktrees: Orca records a new worktree as a child of the caller's worktree.
- Message bodies and prompts are written to a file first and passed with `"$(cat <file>)"`, so the shell never
  expands their content ([gotchas](./docs/gotchas.md#shell-expansion-inside-messages)).
- Never type into another agent's terminal or chat (`orca terminal send`). Reach the two chats through their Run
  mailboxes once they have one.
- A command that waits (`--wait`) gets a Bash timeout above its `--timeout-ms`
  ([gotchas](./docs/gotchas.md#a-mailbox-wait-outlives-its-bash-timeout)).
- The placeholders in `<...>` are the ones of [`agents/README.md`](./agents/README.md#placeholders), filled from the
  env file of step 1: `<team repo>` is this repository's root (`$OAT`), `<ideas dir>` is `$IDEAS_DIR`,
  `<ideas run-id file>` is `$IDEAS_RUN_ID_FILE`, and so on.
- If a command needs approval and does not get it, skip it, say so, and stop.
- The only remote operations are the read-only `gh` checks of step 2. Nothing is pushed.

Every `orca` command here was checked against `orca <command> --help` on Orca 1.4.245. A line marked
`(unverified)` was not run end to end on a reference machine; when its output differs from **Expected**, stop and
report it.

The background for every step is in [`docs/setup-guide.md`](./docs/setup-guide.md).

## Step 1. Read the config

```bash
OAT="$(git rev-parse --show-toplevel)"
test -s "$OAT/config/stack.yaml" && echo "config present"
yq '.stack.id' "$OAT/config/stack.yaml"
yq '[.repos[] | select(.kind == "hub")] | length' "$OAT/config/stack.yaml"
"$OAT/tools/load-config.sh"
STACK_ID="$(yq '.stack.id' "$OAT/config/stack.yaml")"
. "$HOME/.local/share/$STACK_ID/stack.env"
printf '%s\n' "$STACK_ID" "$HUB_PATH" "$IDEAS_DIR" "$TECH_LEAD_DIR" "$IDEAS_RUN_ID_FILE" "$TECH_LEAD_RUN_ID_FILE" "$NOTIFY_MODE"
```

**Expected:** `config present`; a stack id made of lowercase letters, digits and dashes; exactly `1` hub; the loader
reports the env file it wrote; seven non-empty lines, with `$HUB_PATH` an absolute path and the two Run id files
under `~/.local/share/<id>-ideas/` and `~/.local/share/<id>-tech-lead/`.

If `config/stack.yaml` is missing, tell the human to copy `config/stack.example.yaml` to `config/stack.yaml` and fill
it, then stop. If the loader's flags or output differ from the above, follow [`tools/README.md`](./tools/README.md),
which wins.

Shell variables do not survive between Bash calls. Start every later step's commands with:

```bash
OAT="$(git rev-parse --show-toplevel)"; STACK_ID="$(yq '.stack.id' "$OAT/config/stack.yaml")"; . "$HOME/.local/share/$STACK_ID/stack.env"
```

## Step 2. Check the prerequisites

```bash
orca --version; claude --version; git --version; gh --version | head -1; tmux -V; jq --version; yq --version; engram version
gh auth status
claude mcp list | grep -i engram
for r in $(yq '.repos[].remote' "$OAT/config/stack.yaml"); do gh repo view "$r" --json nameWithOwner -q .nameWithOwner; done
yq '.repos[].path' "$OAT/config/stack.yaml" | while read -r p; do p="${p/#\~/$HOME}"; git -C "$p" rev-parse --abbrev-ref HEAD || echo "MISSING $p"; done
orca skills get orchestration --full | head -5
```

**Expected:**

- Orca `1.4.245` or newer; every other tool prints a version ([README, Prerequisites](./README.md#prerequisites)).
- `gh auth status` reports a logged-in account.
- One line naming `engram` as `Connected`.
- One `owner/repo` per repository in the config, no error.
- One branch name per repository, no `MISSING` line.
- Markdown front matter that starts `name: orchestration`.

On a failure, the fix is in [`docs/setup-guide.md`](./docs/setup-guide.md#prerequisites). A missing local clone is
cloned with `git clone` into the path the config names.

> **HUMAN — logins.** If `gh auth status` fails, ask the human to run `gh auth login` in a terminal. If `claude`
> reports no login, ask the human to log in to Claude Code. Wait for both.

> **HUMAN — Orca settings.** Ask the human to open the Orca app's settings and confirm:
> Chat UI **on**, «Agent sleep» **off**, «Agent Dashboard» **on**. Wait for their confirmation.
> Why: [`docs/gotchas.md`](./docs/gotchas.md#agent-sleep-must-stay-off).

If gentle-ai is installed (`gentle-ai --version` answers), also run the per-clone setup of
[`docs/delivery-model.md`](./docs/delivery-model.md#when-gentle-ai-is-installed) for every non-hub repository.

## Step 3. Register the repositories in Orca

```bash
yq '.repos[].path' "$OAT/config/stack.yaml" | while read -r p; do orca repo add --path "${p/#\~/$HOME}" --json >/dev/null && echo "added ${p}"; done
orca repo list --json | jq -r '.. | objects | select(has("path")) | .path' | sort -u
```

**Expected:** one `added` line per repository, and the list contains every repository path of the config, expanded.
A repository that was already registered is fine. The JSON path in the second line is `(unverified)` on 1.4.245; if
it prints nothing, read `orca repo list --json` whole and check the paths by eye.

## Step 4. Create the durable folders and the two hub worktrees

```bash
mkdir -p "$IDEAS_DIR/briefs" "$TECH_LEAD_DIR"/{briefs,reports,pr-bodies} "$HOME/.local/share/$STACK_ID/bootstrap"
cp "$OAT/agents/templates/after-start-ideas.md" "$IDEAS_DIR/after-start.md"
cp "$OAT/agents/templates/after-start-tech-lead.md" "$TECH_LEAD_DIR/after-start.md"
cp "$OAT/agents/team-conventions.md" "$TECH_LEAD_DIR/briefs/team-conventions.md"
HUB_MAIN="$(yq '.repos[] | select(.kind == "hub") | .main_branch' "$OAT/config/stack.yaml")"
orca worktree create --repo path:"$HUB_PATH" --name Ideas --base-branch "$HUB_MAIN" --no-parent --json
```

Read the new worktree's absolute path from the output and keep it as `<ideas worktree>`. Then:

```bash
orca worktree create --repo path:"$HUB_PATH" --name Tech-lead --parent-worktree path:<ideas worktree> --base-branch "$HUB_MAIN" --json
orca worktree list --repo path:"$HUB_PATH" --json
```

Keep the second worktree's path as `<tech-lead worktree>`. Write both to the bootstrap folder, one path per file, so
later steps can read them:

```bash
printf '%s\n' '<ideas worktree>' > "$HOME/.local/share/$STACK_ID/bootstrap/ideas-path.txt"
printf '%s\n' '<tech-lead worktree>' > "$HOME/.local/share/$STACK_ID/bootstrap/tech-lead-path.txt"
```

Now fill every placeholder of the [placeholders table](./agents/README.md#placeholders) in the two copied
checklists, `$IDEAS_DIR/after-start.md` and `$TECH_LEAD_DIR/after-start.md`, with this machine's values from the env
file (for `<stack.name>`, `$STACK_NAME`). Use the Edit tool, not `sed -i`. Leave the per-message placeholders as
they are: `<delivery-id>`, `<own run id>`, `<old run id>`, `<dispatch-id>`, `<file>`, `<n>`, `<encoded path>` and
`<absolute path>`. Replace `<path of every repo in repos[]>` with the expanded `path` of every repository.

**Expected:** two worktrees in the hub, «Ideas» top-level and «Tech-lead» with «Ideas» as its parent; the two
checklists hold no table placeholder left (`grep -n '<[A-Za-z]' "$IDEAS_DIR/after-start.md" "$TECH_LEAD_DIR/after-start.md"`
prints only the per-message placeholders listed above). The `create` lines are built from
`orca worktree create --help` `(unverified)`. If a worktree with that name already exists, reuse it instead of
creating a second one.

## Step 5. Open both chats; each creates its Run and its Run id file

A Run is bound to the session that creates it, so you cannot create the two Runs yourself: each chat creates its
own ([gotchas](./docs/gotchas.md#a-run-belongs-to-the-session-that-created-it)). You launch each chat with a first
prompt that does only that.

Write Ideas' first prompt to `~/.local/share/<id>/bootstrap/ideas-first.md`, with the values filled in:

```text
You are Ideas, the analyst chat of the <stack.name> agent team. Your role card is
<team repo>/agents/roles/ideas/SKILL.md and your checklist is <ideas dir>/after-start.md.
This is a FIRST START: there is no prior session, so skip the identity step. Do only steps 2 and 3 of your
checklist now. Step 2, Run: check `orca orchestration run-current --json`; when it shows no Run, create one with
`orca orchestration run-create --objective "<stack.name> Ideas inbox" --json`, write its id, only the id, on one
line, to <ideas run-id file>, and confirm that `orca orchestration run-current --json` shows the same id. Step 3:
arm your mailbox wait exactly as the checklist says. Then stop. Your next instructions arrive in your Run mailbox
with the subject prefix [Bootstrap].
```

Write the Tech-lead's to `~/.local/share/<id>/bootstrap/tech-lead-first.md` the same way, with
`<team repo>/agents/roles/tech-lead/SKILL.md`, `<tech-lead dir>/after-start.md`, the objective
`"<stack.name> tech lead"` (the one its checklist uses) and `<tech-lead run-id file>`. Add one line: "Messages with
the subject prefix [PR monitor] or [Worker watch] may arrive before your checklist; read and acknowledge them."

Launch Ideas, wait for its Run id file, then launch the Tech-lead:

```bash
B="$HOME/.local/share/$STACK_ID/bootstrap"
orca agent launch --agent claude --worktree path:"$(cat "$B/ideas-path.txt")" --surface chat \
  --model "$(yq '.models.ideas.model' "$OAT/config/stack.yaml")" --effort "$(yq '.models.ideas.effort' "$OAT/config/stack.yaml")" \
  --prompt "$(cat "$B/ideas-first.md")" --json
for i in $(seq 1 40); do test -s "$IDEAS_RUN_ID_FILE" && break; sleep 10; done; cat "$IDEAS_RUN_ID_FILE"
```

```bash
B="$HOME/.local/share/$STACK_ID/bootstrap"
orca agent launch --agent claude --worktree path:"$(cat "$B/tech-lead-path.txt")" --surface chat \
  --model "$(yq '.models.tech_lead.model' "$OAT/config/stack.yaml")" --effort "$(yq '.models.tech_lead.effort' "$OAT/config/stack.yaml")" \
  --prompt "$(cat "$B/tech-lead-first.md")" --json
for i in $(seq 1 40); do test -s "$TECH_LEAD_RUN_ID_FILE" && break; sleep 10; done; cat "$TECH_LEAD_RUN_ID_FILE"
```

Give each of these Bash calls a timeout of 600000 ms (the loop waits up to 400 s).

**Expected:** each launch reports a chat (`outcome.kind`), the Orca app shows a Claude chat tab in each worktree,
each Run id file holds one id on one line, not `null`, and each chat ends its turn with its mailbox wait armed in
the background. The launch lines are built from `orca agent launch --help`
`(unverified)` as exact lines.

> **HUMAN — permission prompts.** A new chat may stop on a permission prompt for its first `orca` command. Ask the
> human to watch the Agent Dashboard and approve the `orca orchestration` commands of the two chats.

> **HUMAN — when a launch does not give a chat.** If a launch reports a terminal instead of a chat, or fails, ask
> the human to open a new Claude agent tab on that worktree in the Orca app and paste the first prompt file's
> content as the first message **in that same tab**. Wait for the Run id file as above.

## Step 6. Start the monitors

The PR monitor and the permission watch run in tmux, in the sessions `<id>-pr-monitor` and `<id>-worker-watch`, and
post to the Tech-lead's Run mailbox (`notify_mode: run`). These are the start lines of
[`tools/README.md`](./tools/README.md#start), with the env file of step 1; stop any copy already running first:

```bash
ENV_FILE="$HOME/.local/share/$STACK_ID/stack.env"
tmux kill-session -t "$STACK_ID-pr-monitor" 2>/dev/null; tmux kill-session -t "$STACK_ID-worker-watch" 2>/dev/null
tmux new-session -d -s "$STACK_ID-pr-monitor"   "STACK_ENV_FILE=$ENV_FILE $OAT/tools/pr-monitor.sh"
tmux new-session -d -s "$STACK_ID-worker-watch" "STACK_ENV_FILE=$ENV_FILE $OAT/tools/worker-watch.sh"
tmux ls
STACK_ENV_FILE="$ENV_FILE" "$OAT/tools/pr-monitor.sh" --notify "alive check"
tail -n 1 "$MONITOR_DIR/monitor.log"
```

**Expected:** `tmux ls` lists `<id>-pr-monitor` and `<id>-worker-watch`; the last line of `monitor.log` is the
orchestration send receipt; the Tech-lead chat wakes on `[PR monitor] alive check`. A first poll of the PR monitor
notifies nothing: it records a baseline. With `notify_mode: terminal`, use the
[`terminal` mode](./tools/README.md#terminal-mode) start lines instead. The Tech-lead's checklist (its step 4) stops
and restarts both sessions under the same names; that is expected.

## Step 7. Both chats run their after-start checklists

Ideas started first and its Run exists, so the order is already right. Send each chat, through its own Run, the
instruction to run its checklist. Write each body first, to `~/.local/share/<id>/bootstrap/ideas-checklist.md` and
`~/.local/share/<id>/bootstrap/tech-lead-checklist.md`, with `<checklist path>` set to `<ideas dir>/after-start.md`
and `<tech-lead dir>/after-start.md`:

```text
Run your after-start checklist, <checklist path>, now, as a FIRST START: the identity check is skipped, your Run
already exists (keep it), and your mailbox wait is armed (keep exactly one armed). On a first start Ideas does not
write to the Tech-lead: the Tech-lead's first message to Ideas' Run is the handshake, and Ideas answers it. Report
the result in this chat when you are done.
```

```bash
B="$HOME/.local/share/$STACK_ID/bootstrap"
orca orchestration send --to "run:$(cat "$IDEAS_RUN_ID_FILE")" --type status --subject "[Bootstrap] run your after-start checklist" --body "$(cat "$B/ideas-checklist.md")" --json
orca orchestration send --to "run:$(cat "$TECH_LEAD_RUN_ID_FILE")" --type status --subject "[Bootstrap] run your after-start checklist" --body "$(cat "$B/tech-lead-checklist.md")" --json
```

**Expected:** each send answers with a message id. Each chat's armed wait wakes it (or, when its wait is gone, Orca's
fallback nudge does, within about two minutes); each chat reads its mail and runs its checklist, and you see both
working in the Orca app. The Tech-lead's checklist sends Ideas the handshake, `[Tech-lead] ready`, and Ideas answers
with `[From Ideas] handshake received`.

> **HUMAN — when a chat does not react.** If a chat shows no new turn two minutes after the send, ask the human to
> paste the same body into that chat **in its existing tab** (not a new tab: a new tab is a fresh session).

## Step 8. Prove the mailbox round trip Ideas → Tech-lead → Ideas

Pick a fresh token, such as `BOOT-` plus the current Unix time, and write this body to
`~/.local/share/<id>/bootstrap/roundtrip.md`:

```text
Mailbox round-trip test. Send the Tech-lead, through its Run, a [From Ideas] message that carries the token
<token> and asks it to echo the token back to you. When its [Tech-lead] reply with the same token arrives, write
the token, only the token, to <IDEAS_DIR>/roundtrip-ok.txt, and tell the product owner in this chat that the
round trip worked.
```

```bash
B="$HOME/.local/share/$STACK_ID/bootstrap"
: > "$IDEAS_DIR/roundtrip-ok.txt"
orca orchestration send --to "run:$(cat "$IDEAS_RUN_ID_FILE")" --type status --subject "[Bootstrap] mailbox round trip" --body "$(cat "$B/roundtrip.md")" --json
for i in $(seq 1 50); do test -s "$IDEAS_DIR/roundtrip-ok.txt" && break; sleep 10; done; cat "$IDEAS_DIR/roundtrip-ok.txt"
```

Give the Bash call a timeout of 600000 ms.

**Expected:** the file holds exactly your token. That proves Ideas → Tech-lead (Ideas' send reached the Tech-lead's
Run and woke it) and Tech-lead → Ideas (the echo reached Ideas' Run and woke it). The Ideas chat shows the
confirmation.

If the file stays empty, apply the **HUMAN** fallback of step 7 to the chat that did not react, then re-run this
step with a new token.

## Done

Report to the human:

- the two worktree paths, the two Run ids, and the monitor sessions;
- the round-trip token, and whether it came back;
- every step that needed a fallback or failed, and every `(unverified)` line whose output differed from
  **Expected**.

Leave the bootstrap folder `~/.local/share/<id>/bootstrap/` in place; it holds no secret, and the human may delete
it. From now on the human talks to the Ideas chat. After a reboot, follow [`docs/reboot.md`](./docs/reboot.md).
