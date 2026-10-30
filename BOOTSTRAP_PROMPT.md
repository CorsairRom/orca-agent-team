# Bootstrap prompt: install the agent team from this Orca chat

You are the **installing chat**: a Claude Code chat in Orca that the human asked to install this agent team. You
are neither Ideas nor the Tech-lead. Execute this file end to end, in order. At the end:

- `config/stack.yaml` describes the human's stack;
- the Ideas chat and the Tech-lead chat run in two worktrees of the hub repository, each launched by you as a fresh
  chat, each with its own Run and run-id file;
- the two monitors run in tmux, started by the Tech-lead;
- the handshake and one message Ideas → Tech-lead → Ideas went through;
- you tell the human to talk to Ideas.

## Rules while you execute

- Run every step's commands, compare the output with **Expected**, and only then go on. On a mismatch, stop and tell
  the human which step failed, the command, and its output. Do not improvise a different path.
- A step marked **HUMAN** needs the human: a login, an Orca setting, or a permission prompt. These are the only
  HUMAN steps. Tell the human exactly what to do, then stop and wait for their answer before you go on.
- When this file says **ask the human**, ask one question at a time, wait for the answer, and go on.
- You may run in any Orca workspace. Run the commands from this repository's clone, `<team repo>`: every block
  starts with `cd` to it, because the Bash tool keeps its working directory only within one session. Never run
  them from inside the hub's Ideas or Tech-lead worktrees.
- Message bodies and prompts are written to a file first and passed with `"$(cat <file>)"`, so the shell never
  expands their content ([gotchas](./docs/gotchas.md#shell-expansion-inside-messages)).
- Never type into another agent's chat or terminal (`orca terminal send`). Reach Ideas and the Tech-lead through
  their Run mailboxes.
- Prefer the editor tool over `sed -i` and command substitutions in shell commands; auto-mode permission checks may
  block them. If a command needs approval and does not get it, skip it, say so, and stop.
- Remote operations are read-only: `gh` checks and `git clone`. Nothing is pushed. Leave the global settings and
  plugins of the human's agents, and the settings of the human's clones, as they are.
- Every placeholder in `<...>`, its env-file key, who fills it and when, is in the
  [placeholder table](./agents/README.md#placeholders). Once step 3 has run, the env file sets the keys:
  `<ideas dir>` is `$IDEAS_DIR`, `<bootstrap dir>` is `$BOOTSTRAP_DIR`, and so on.
- No bash step reads `config/stack.yaml`: you read it with the file tool, and every bash step takes its values from
  the env file of step 3.
- The Bash tool runs the human's login shell, which may be zsh. A block that needs bash (`${!var}`, `for ((...))`,
  arrays) is written as `bash -c '...'`; run it exactly so.

Every `orca` command here matches `orca <command> --help` on the minimum Orca version in the
[README](./README.md#prerequisites). A line marked `(unverified)` has an output shape the help does not state; when
its output differs from **Expected**, stop and report it. The background for every step is in
[`docs/setup-guide.md`](./docs/setup-guide.md).

## Step 1. Check the prerequisites

```bash
cd <team repo>
orca --version; orca status --json | head -20
claude --version; git --version; gh --version | head -1; tmux -V; jq --version; engram version
gh auth status
claude mcp list | grep -i engram
orca skills get orchestration --full | head -3
```

**Expected:**

- Every tool prints a version at or above the minimum versions in the [README](./README.md#prerequisites), and
  `orca status` reports the app as running.
- `gh auth status` reports a logged-in account.
- One line naming `engram`, `Connected`.
- Front matter with `name: orchestration`.

A missing tool is installed as [`docs/setup-guide.md`](./docs/setup-guide.md#prerequisites) says; ask the human
before installing anything.

> **HUMAN — logins.** If `gh auth status` reports no login, ask the human to run `gh auth login` in a terminal. If
> `claude` reports no login, ask the human to log in to Claude Code. Wait for both.

> **HUMAN — Orca settings.** Ask the human to open the Orca app's settings and confirm three settings: Chat UI
> **on**, "Agent sleep" **off**, "Agent Dashboard" **on**. Wait for their confirmation. Why:
> [`docs/setup-guide.md`](./docs/setup-guide.md#orca-settings).

## Step 2. The config

Read `<team repo>/config/stack.yaml` with the file tool.

**If it exists,** show the human its `stack`, `repos` and `models` sections and go to step 3.

**If it is missing, build it with the human.** Start from a copy of
[`config/stack.example.yaml`](./config/stack.example.yaml), whose comments explain every key, and **ask the
human**, one question at a time:

1. **Stack id**: lowercase letters, digits and dashes, such as `acme`. It names every local folder of the team.
   Propose a display name (`stack.name`) from it.
2. **The repositories of the stack.** For each one: its local path, or its GitHub `owner/repo` and the path to
   clone it to. Right after the answer, clone each repository that has no local clone yet, after telling the
   human: `gh repo clone <owner/repo> <path>`. Then ask which one is the **hub**, where Ideas and the Tech-lead
   live and the planning documents are kept, and the kind of each other one (`frontend`, `backend`, `docs`,
   `infra` or `other`). Fill `name`, `remote` and `main_branch` yourself from each clone, and show them:

   ```bash
   cd <team repo>
   git -C <path> remote get-url origin
   git -C <path> symbolic-ref --short refs/remotes/origin/HEAD
   ```

   `remote` is the `owner/repo` part of the first line. `main_branch` is the second line without its `origin/`
   prefix: `origin/main` gives `main`. `name` is the clone's folder name, the name Orca gives a repository it
   registers (`(unverified)`: `orca repo add --help` does not say); step 4 reads the registered name back. Every
   command of the team selects a repository by its path (`--repo path:<path>`), so the name is for display.

3. **Languages**: of the conversation with the product owner, of artifacts (code, docs, PRs), and of app copy.
   Propose `en` for all three.
4. **Models**: propose the example's model and effort per role and seniority, and ask whether to change any.

Every other key keeps the example's value: `memory.engram_project` is the hub's `name`, `memory.topic_prefix` is the
stack id, and `hub`, `delivery`, `conventions` (empty), `orca` and `monitors` stay as in the example. Write the
result to `<team repo>/config/stack.yaml` with the editor tool, show the whole file to the human, and ask them to
confirm it. Change what they ask, then go on.

## Step 3. Write the env file

Write the env file and the conventions file from `config/stack.yaml` by following
[Writing the env file](./tools/README.md#writing-the-env-file) in `tools/README.md`, all four of its steps. It
validates the config first: when it finds a problem, tell the human every problem, fix them in `config/stack.yaml`
with the human, and run this step again.

**Expected:** its read-back shows `HUB_PATH` as an absolute path, `REPO_COUNT` equal to the number of repositories,
the model and effort of Ideas and the Tech-lead, and one line per repository.

Shell variables do not survive between Bash calls, so every later bash block starts by sourcing the env file:
`. ~/.local/share/<stack.id>/stack.env`, with `<stack.id>` filled in.

## Step 4. Check the clones and register the repositories in Orca

```bash
bash -c '
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
for ((i = 0; i < REPO_COUNT; i++)); do r="REPO_${i}_REMOTE"; gh repo view "${!r}" --json nameWithOwner -q .nameWithOwner; done
for ((i = 0; i < REPO_COUNT; i++)); do p="REPO_${i}_PATH"; git -C "${!p}" rev-parse --abbrev-ref HEAD || echo "MISSING ${!p}"; done
'
```

**Expected:** one `owner/repo` per repository, no error; one branch name per repository, no `MISSING` line. A
missing clone is cloned with `git clone` from its `REPO_<i>_REMOTE` into its `REPO_<i>_PATH`, after telling the
human.

Register every repository that Orca does not list yet:

```bash
bash -c '
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
for ((i = 0; i < REPO_COUNT; i++)); do p="REPO_${i}_PATH"
  orca repo list --json | jq -e --arg p "${!p}" "any(.. | objects; .path? == \$p)" >/dev/null || orca repo add --path "${!p}" --json >/dev/null
done
'
```

Then read the registration back:

```bash
bash -c '
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
list=$(orca repo list --json)
for ((i = 0; i < REPO_COUNT; i++)); do p="REPO_${i}_PATH"; n="REPO_${i}_NAME"
  name=$(jq -r --arg p "${!p}" "[.. | objects | select(.path? == \$p)][0].displayName // \"NOT-REGISTERED\"" <<<"$list")
  echo "${!p} registered=$name config=${!n}"
done
'
```

**Expected:** one line per repository, none `NOT-REGISTERED`: every `REPO_<i>_PATH` appears in `orca repo list`.
`displayName` is the field `orca repo list --json` prints for a repository's name. Where `registered` differs from
`config`, write the registered name into that repository's `name` in `config/stack.yaml` with the editor tool, and
write the env file again (step 3).

## Step 5. Create the durable folders, the Engram project and the two hub worktrees

Engram refuses an explicit project it holds no observation of (`unknown_project`), and the chats pass the project
explicitly ([memory](./agents/README.md#memory)). So you create it once, with one note, unless it already holds
some:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
mkdir -p "$IDEAS_DIR/briefs" "$TECH_LEAD_DIR/briefs" "$TECH_LEAD_DIR/reports" "$TECH_LEAD_DIR/pr-bodies" "$BOOTSTRAP_DIR"
engram projects list | awk -v p="$ENGRAM_PROJECT" '$1 == p && $2 > 0' | grep -q . || engram save "$STACK_NAME agent team installed" "The installing chat created this project for the $STACK_NAME agent team." --type config --project "$ENGRAM_PROJECT"
engram projects list | awk -v p="$ENGRAM_PROJECT" '$1 == p'
```

**Expected:** one line: the project, with `1 obs` or more. Engram may also print an update notice; ignore it.

List the hub's worktrees first:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
orca worktree list --repo path:"$HUB_PATH" --json
```

If the list shows a worktree named Ideas, keep its path as `<ideas worktree>` and skip the next block; otherwise
create it:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
orca worktree create --repo path:"$HUB_PATH" --name Ideas --base-branch "$HUB_MAIN_BRANCH" --no-parent --json
```

Orca chooses where a worktree lives, which need not be next to the hub clone: read the worktree's absolute path
from the output, never assume it, and keep it as `<ideas worktree>`. The same for the Tech-lead: if the list
showed a worktree named Tech-lead, keep its path as `<tech-lead worktree>` and skip the next block; otherwise:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
orca worktree create --repo path:"$HUB_PATH" --name Tech-lead --parent-worktree path:<ideas worktree> --base-branch "$HUB_MAIN_BRANCH" --json
orca worktree list --repo path:"$HUB_PATH" --json
```

Keep the Tech-lead's path as `<tech-lead worktree>`, and write both down for later steps:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
printf '%s\n' '<ideas worktree>' > "$BOOTSTRAP_DIR/ideas-path.txt"
printf '%s\n' '<tech-lead worktree>' > "$BOOTSTRAP_DIR/tech-lead-path.txt"
```

**Expected:** two worktrees in the hub, Ideas top-level (`--no-parent`) and Tech-lead with Ideas as its parent.
`--no-parent` matters: without it, Orca uses the parent it infers from the current context
(`orca worktree create --help`). The field that holds the path in the JSON is `(unverified)`; read it from the
output.

## Step 6. Launch Ideas and the Tech-lead

A Run is bound to the session that created it, so you do not create their Runs: each chat creates its own in its
first turn, from its after-start checklist ([gotchas](./docs/gotchas.md#a-run-is-bound-to-the-session-that-created-it)).

Write five files with the editor tool (long text inside shell commands breaks on quoting, and auto-mode permission
checks may block command substitutions), with every value filled in (`<stack.id>`, `<stack.name>` and the absolute
`<team repo>`):

- `<bootstrap dir>/ideas-first.md`, the first prompt of Ideas:

  ```text
  You are Ideas, the analyst chat of the <stack.name> agent team. Your role card is
  <team repo>/agents/roles/ideas/SKILL.md. Read <team repo>/agents/templates/after-start-ideas.md whole and run it
  now as a FIRST START. The stack id is <stack.id>; the team repository is <team repo>.
  ```

- `<bootstrap dir>/tech-lead-first.md`, the same with `You are the Tech-lead, the coordinator chat`,
  `agents/roles/tech-lead/SKILL.md` and `agents/templates/after-start-tech-lead.md`;
- `<ideas dir>/resume-prompt.txt` and `<tech-lead dir>/resume-prompt.txt`, the same two texts with `RESUME` instead
  of `FIRST START`. The human pastes them after a reboot ([`docs/reboot.md`](./docs/reboot.md)).

Launch Ideas, and wait for its run-id file:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
orca agent launch --agent claude --surface chat --worktree path:"$(cat "$BOOTSTRAP_DIR/ideas-path.txt")" \
  --model "$MODEL_IDEAS" --effort "$EFFORT_IDEAS" \
  --prompt "$(cat "$BOOTSTRAP_DIR/ideas-first.md")" --json
for i in $(seq 1 50); do test -s "$IDEAS_RUN_ID_FILE" && break; sleep 10; done; cat "$IDEAS_RUN_ID_FILE"
```

Then the Tech-lead, and wait for its run-id file and for the handshake confirmation:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
orca agent launch --agent claude --surface chat --worktree path:"$(cat "$BOOTSTRAP_DIR/tech-lead-path.txt")" \
  --model "$MODEL_TECH_LEAD" --effort "$EFFORT_TECH_LEAD" \
  --prompt "$(cat "$BOOTSTRAP_DIR/tech-lead-first.md")" --json
for i in $(seq 1 50); do test -s "$TECH_LEAD_DIR/handshake-ok.txt" && break; sleep 10; done
cat "$TECH_LEAD_RUN_ID_FILE" "$TECH_LEAD_DIR/handshake-ok.txt"
```

Give each of these Bash calls a timeout of 600000 ms (each loop waits up to 500 s).

**Expected:**

- Each launch answers with `outcome.kind` naming a chat, and a chat tab appears in its worktree.
- Each run-id file holds one id on one line, not `null`.
- `handshake-ok.txt` holds Ideas' Run id: the Tech-lead started the monitors, sent `[Tech-lead] ready` to Ideas'
  Run, Ideas answered with `[From Ideas] handshake received`, and the Tech-lead recorded it.

If a launch reports a terminal instead of a chat, stop: the team needs chats; tell the human what
`receipt.detail` says.

> **HUMAN — permission prompts.** A new chat may stop on a permission prompt for its first `orca` command. Ask the
> human to watch the Agent Dashboard and approve the `orca orchestration` commands of the two chats.

## Step 7. Check the monitors

The PR monitor and the permission watch run in the tmux sessions `<stack.id>-pr-monitor` and
`<stack.id>-worker-watch`, and post to the Tech-lead's Run mailbox. The Tech-lead started them in its first turn
(its checklist step 4), not you: a monitor sends under the Orca identity of the chat that started it, and you are
closed after the install ([gotchas](./docs/gotchas.md#a-tmux-session-sends-under-the-identity-it-was-started-with)).
You only check them:

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
tmux ls
tail -n 1 "$MONITOR_DIR/monitor.log"
orca orchestration inbox --limit 100 --json | jq -r '[.. | objects | select(has("from_handle") and has("subject"))] | unique_by(.id) | sort_by(.created_at)[] | select((.subject | startswith("[PR monitor] alive check")) or (.subject | startswith("[Tech-lead] ready"))) | "\(.created_at)  \(.from_handle)  \(.subject)"'
```

**Expected:** `tmux ls` lists both sessions; the last line of `monitor.log` is the send receipt of the alive check;
the newest `[PR monitor] alive check` and the newest `[Tech-lead] ready` show the same `from_handle`, the Tech-lead's
([Check the sender](./tools/README.md#check-the-sender)). A missing session, a missing alive check or another
sender: send the Tech-lead a `[Bootstrap]` message through its Run asking it to run its checklist step 4 again,
then check once more.

## Step 8. Prove the round trip Ideas → Tech-lead → Ideas

Pick a fresh token, such as `BOOT-` plus the current Unix time, and write this body to
`<bootstrap dir>/roundtrip.md`, with the values filled in:

```text
Mailbox round-trip test. Send the Tech-lead, through its Run, a [From Ideas] message that carries the token
<token> and asks it to echo the token back to you. When its [Tech-lead] reply with the same token arrives, write
the token, only the token, to <ideas dir>/roundtrip-ok.txt.
```

```bash
. ~/.local/share/<stack.id>/stack.env
cd "$TEAM_REPO"
: > "$IDEAS_DIR/roundtrip-ok.txt"
orca orchestration send --to "run:$(cat "$IDEAS_RUN_ID_FILE")" --type status --subject "[Bootstrap] mailbox round trip" --body "$(cat "$BOOTSTRAP_DIR/roundtrip.md")" --json
for i in $(seq 1 50); do test -s "$IDEAS_DIR/roundtrip-ok.txt" && break; sleep 10; done; cat "$IDEAS_DIR/roundtrip-ok.txt"
```

Give the Bash call a timeout of 600000 ms.

**Expected:** the send answers with a message id, and the file holds exactly your token. That proves Ideas →
Tech-lead (Ideas' send reached the Tech-lead's Run and Orca prompted the Tech-lead) and Tech-lead → Ideas (the
echo reached Ideas' Run and Orca prompted Ideas).

**When a chat does not react** in step 6, 7 or 8: send it a `[Bootstrap] ping` through its Run, which prompts it
again, and wait once more. If it still does not react, stop and report which chat, which step and what its tab
shows.

## Step 9. Hand over to Ideas

Report to the human:

- the path of `config/stack.yaml`, the two worktree paths, the two Run ids, and the two monitor sessions;
- the handshake and the round-trip token, and whether each came back;
- every step that failed or needed a HUMAN action, and every `(unverified)` line whose output differed from
  **Expected**.

Then tell the human: **from now on, talk to the Ideas chat**, in the hub's Ideas worktree. After a reboot, follow
[`docs/reboot.md`](./docs/reboot.md). The folder `<bootstrap dir>` holds no secret; the human may delete it.
