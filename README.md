# orca-agent-team

A two-chat agent team for [Orca](https://github.com/stablyai/orca) and Claude Code. An **Ideas** chat turns the
product owner's requests into product requirements, and a **Tech-lead** chat plans, dispatches and reviews the work
of supervised workers across the repositories of one product stack. The stack is described in one config file, so
the same team runs on any set of repositories.

To install it, you paste one prompt into a new Orca chat ([Install](#install)). That chat clones this repository if
needed, builds the config with you, and launches the Ideas and Tech-lead chats, talking through Run mailboxes and
ready for a first request.

## The roles

| Role | What it is | What it does |
| --- | --- | --- |
| **Ideas** | A permanent Claude Code chat in Orca, in the hub repository's "Ideas" worktree | The only agent the product owner talks to. Refines a request into a PRD (or a reasoned discard), researches read-only, brings the product owner one decision at a time, and hands the work to the Tech-lead |
| **Tech-lead** | A permanent Claude Code chat in Orca, in the hub's "Tech-lead" worktree, a child of "Ideas" | Triages the work, writes one brief per work unit, starts one supervised worker per unit, merges work units as the [delivery model](./docs/delivery-model.md) says, runs the monitors, and reports to Ideas. It never asks the product owner directly |
| **Workers** | Orca supervised workers (`orca orchestration worker-start`), one per work unit, in their own worktree | Developers per repository kind, an independent reviewer, QA. Each reads its brief, works, and reports once with `worker_done` |

The role cards are in [`agents/roles/`](./agents/roles/) and the operating manual is
[`agents/README.md`](./agents/README.md).

```
product owner ── talks only to Ideas
 └─ Ideas (chat, hub worktree "Ideas") ── its own Run: an inbox
     └─ Run-to-Run mail, never a worker relation
         └─ Tech-lead (chat, hub worktree "Tech-lead") ── its own standing Run
              ├─ workers, one per work unit (worker-start --worktree new-child)
              ├─ PR monitor        → the Tech-lead's Run mailbox
              └─ permission watch  → the Tech-lead's Run mailbox
Shared memory: one Engram project, read and written by both chats
```

## How they talk

Each coordinator owns one Orca **Run**, which is its mailbox. Its id lives in a file:
`~/.local/share/<stack.id>/ideas/run-id.txt` for Ideas and `~/.local/share/<stack.id>/tech-lead/run-id.txt` for the
Tech-lead (another [team](#several-teams) keeps them under `~/.local/share/<stack.id>/teams/<team id>/`). A message
goes to the peer's Run:

```bash
orca orchestration send --to "run:$(cat ~/.local/share/acme/tech-lead/run-id.txt)" --type status \
  --subject "[From Ideas] <subject>" --body "$(cat <file>)"
```

- The body is written to a file first and passed with `"$(cat <file>)"`, so the shell never expands its content.
- Subjects start with `[From Ideas]` or `[Tech-lead]`. The monitors use `[PR monitor]` and `[Worker watch]`.
- Each chat receives its mail by [the mailbox rule](./agents/README.md#the-mailbox-rule): Orca prompts the idle
  chat when mail arrives, and the chat checks, reads, acts and acknowledges.
- Nobody types into another agent's chat or terminal.
- Workers reach the Tech-lead through its Run, with `worker_done`, `ask`, `escalation` and heartbeats.

The full protocol is in [`docs/setup-guide.md`](./docs/setup-guide.md#the-mailbox-protocol).

## Prerequisites

Every `orca` command in these docs matches its `--help` on the minimum Orca version below, and every other file
refers to this table for versions.

| Need | Minimum version | Check | Notes |
| --- | --- | --- | --- |
| Orca desktop app and its `orca` CLI | **1.4.245** | `orca --version` | Chat UI on, "Agent sleep" off, "Agent Dashboard" on ([setup guide](./docs/setup-guide.md#orca-settings)) |
| Claude Code | any current release | `claude --version` | Logged in. Ideas, the Tech-lead and the workers are Claude Code sessions |
| `git` | any current release | `git --version` | Local clones of every repository in the config |
| GitHub CLI `gh` | any current release | `gh --version`; `gh auth status` | Logged in, with access to every repository in the config. The PR monitor uses it |
| `tmux` | 3.2, the first whose `new-session` takes `-e` (tmux `CHANGES`) | `tmux -V` | The two monitors run in detached tmux sessions |
| `jq` | 1.6 | `jq --version` | The tools and the bootstrap read Orca's JSON output with it |
| `bash` | 4 | `bash --version` | The tools and the `bash -c '...'` blocks of the bootstrap |
| Engram, registered as Claude Code's MCP server | 3.4.0, the version the [project rule](./agents/README.md#memory) is checked on | `engram version`; `claude mcp list` | The shared memory of both chats. Install it as [its own README](https://github.com/Gentleman-Programming/engram#readme) says ([setup guide](./docs/setup-guide.md#engram)) |

The tools also need the GNU core utilities; [`tools/README.md`](./tools/README.md#requirements) lists them.

## Install

1. **HUMAN:** in the Orca app's settings, set Chat UI **on**, "Agent sleep" **off** and "Agent Dashboard" **on**.
2. Open a new Claude Code chat in any Orca workspace (a folder workspace works too) and paste this prompt, with
   `<owner>` set to the GitHub account you install from (this repository's owner, or your fork):

   ```text
   Install the orca-agent-team agent team in this Orca. If there is no local clone of
   https://github.com/<owner>/orca-agent-team yet, ask me where to put it and clone it there. Then read
   BOOTSTRAP_PROMPT.md in that clone whole and execute it step by step; start every command block with a cd to
   the clone. You are the installing chat, not one of the team's chats. Ask me one question at a time, and stop
   only where a step says HUMAN.
   ```

3. Answer its questions. When `config/stack.yaml` does not exist yet, the chat builds it with you: the stack id, the
   repositories of the stack, the languages and the models. Approve the permission prompts the Agent Dashboard
   shows, and log in to `gh` or Claude Code if it asks.
4. At the end, the Ideas chat and the Tech-lead chat are open in the hub repository, each with its own Run, the
   monitors run, and one message has gone Ideas → Tech-lead → Ideas. **Talk to Ideas.**

What the installing chat does, step by step, is [`BOOTSTRAP_PROMPT.md`](./BOOTSTRAP_PROMPT.md). After a reboot,
follow [`docs/reboot.md`](./docs/reboot.md). To remove the team, see the
[uninstall steps](./docs/setup-guide.md#uninstall).

## Several teams

Two large features that differ should not share one Ideas queue and one Tech-lead context. One stack can run
several teams, each with its own Ideas, Tech-lead, Runs, monitors and backlog, on the same config, hub and memory.
To add one, paste the install prompt into a new Orca chat with this sentence added: `Install a new team named
<team id> on the existing stack.` What is per team and what is shared: [teams](./tools/README.md#teams).

## Configuring the stack

Everything stack-specific lives in `config/stack.yaml`, your local copy; `.gitignore` keeps it out of commits. The commented example is [`config/stack.example.yaml`](./config/stack.example.yaml); it uses a
made-up stack called "acme".

| Section | What it sets |
| --- | --- |
| `stack` | `id` (lowercase, digits and dashes) names the local-share tree `~/.local/share/<id>/`, which holds every local path of the team; `name` is for display |
| `repos[]` | Every repository of the stack: Orca name, local path, GitHub `owner/repo`, main branch and `kind`. Exactly one repository is the `hub`, where Ideas and the Tech-lead live and the planning documents are kept. The other kinds (`frontend`, `backend`, `docs`, `infra`, `other`) pick the developer role card |
| `hub` | Where the hub keeps PRDs, decisions and the backlog |
| `delivery` | The switches of the default workflow ([delivery model](./docs/delivery-model.md)) |
| `conventions` | Free-form team rules the Tech-lead passes into every brief; a new project starts with none |
| `memory` | The Engram project key every chat uses, and the topic prefix |
| `language` | The language of the conversation with the product owner, of artifacts, and of app copy, plus free-form app-copy rules |
| `models` | Model and effort for Ideas, the Tech-lead and each worker seniority |
| `orca` | The three Orca settings the setup expects |
| `monitors` | Poll intervals, the PR author filter and the merged-PR window |

Nothing parses the YAML locally. A chat reads it and writes a shell-sourceable env file,
`~/.local/share/<id>/stack.env` (one per [team](#several-teams)), which the monitors and the checklists source; how, and every key, is in
[Writing the env file](./tools/README.md#writing-the-env-file).

**After a change to `config/stack.yaml`:** ask Ideas or the Tech-lead of each team to regenerate its `stack.env` from
`config/stack.yaml` ([Writing the env file](./tools/README.md#writing-the-env-file)), then the Tech-lead restarts
the monitors from its own chat ([start lines](./tools/README.md#start)). A new repository also needs `orca repo add`
([setup guide](./docs/setup-guide.md#register-the-repositories)).

## Repository map

| Path | Holds |
| --- | --- |
| [`BOOTSTRAP_PROMPT.md`](./BOOTSTRAP_PROMPT.md) | What the installing chat executes to bring the team up |
| [`config/stack.example.yaml`](./config/stack.example.yaml) | The configuration section, commented |
| [`agents/README.md`](./agents/README.md) | The operating manual: lifecycle, roles, delivery, links to every card and template |
| [`agents/team-conventions.md`](./agents/team-conventions.md) | Rules for everything an agent writes |
| [`agents/roles/`](./agents/roles/) | One card per role |
| [`agents/templates/`](./agents/templates/) | PRD, brief, worker report, test plan, and the after-start checklists of [Ideas](./agents/templates/after-start-ideas.md) and the [Tech-lead](./agents/templates/after-start-tech-lead.md) |
| [`tools/`](./tools/README.md) | The env file, the PR monitor and the permission watch |
| [`docs/setup-guide.md`](./docs/setup-guide.md) | The setup guide, step by step, with the reasons |
| [`docs/reboot.md`](./docs/reboot.md) | What to do after a reboot or when a chat is reopened |
| [`docs/gotchas.md`](./docs/gotchas.md) | Known gotchas of Orca and Claude Code in this setup |
| [`docs/delivery-model.md`](./docs/delivery-model.md) | The default workflow: integration branches, work-unit PRs, who merges what |

## Contributing

- **Keep it generic.** No real product, company, repository, person, URL, id or local path in any file, commit or
  example. Examples use the "acme" stack, and people are named by role: "the product owner", "the Tech-lead".
- Changes go through pull requests, with Conventional Commits in English.
- **Re-verify Orca commands on every Orca upgrade.** Check each `orca` command in the docs against
  `orca <command> --help` and `orca skills get orchestration --full`, and update the minimum version in
  [Prerequisites](#prerequisites). Anything the help does not confirm is marked `(unverified)`.
- **A new gotcha** goes in [`docs/gotchas.md`](./docs/gotchas.md) once it is reproduced: the mechanism, its source
  (a `--help` text, a `man` page or `orca skills get orchestration --full`) or `(unverified)`, how to detect it, and
  what to do.
- **A new repository kind** needs a role card in [`agents/roles/`](./agents/roles/), its `kind` in the config
  example, and a row in [`agents/README.md`](./agents/README.md).
- CI runs shellcheck on `tools/*.sh` and a Markdown link check ([`.github/workflows/ci.yml`](./.github/workflows/ci.yml)).

## License

[MIT](./LICENSE).
