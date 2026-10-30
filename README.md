# orca-agent-team

A two-chat agent team for [Orca](https://github.com/stablyai/orca) and Claude Code. An **Ideas** chat turns the
product owner's requests into product requirements, and a **Tech-lead** chat plans, dispatches and reviews the work
of supervised workers across the repositories of one product stack. The stack is described in one config file, so
the same team runs on any set of repositories.

You clone this repository, fill `config/stack.yaml`, hand [`BOOTSTRAP_PROMPT.md`](./BOOTSTRAP_PROMPT.md) to an AI
in Orca, and end up with both chats running, talking through Run mailboxes, and ready for a first request.

## The roles

| Role | What it is | What it does |
| --- | --- | --- |
| **Ideas** | A permanent Claude Code chat in Orca, in the hub repository's «Ideas» worktree | The only agent the product owner talks to. Refines a request into a PRD (or a reasoned discard), researches read-only, brings the product owner one decision at a time, and hands the work to the Tech-lead |
| **Tech-lead** | A permanent Claude Code chat in Orca, in the hub's «Tech-lead» worktree, a child of «Ideas» | Triages the work, writes one brief per work unit, starts one supervised worker per unit, merges work units into the feature's integration branch, runs the monitors, and reports to Ideas. It never asks the product owner directly |
| **Workers** | Orca supervised workers (`orca orchestration worker-start`), one per work unit, in their own worktree | Developers per repository kind, an independent reviewer, QA. Each reads its brief, works, and reports once with `worker_done` |

The role cards are in [`agents/roles/`](./agents/roles/) and the operating manual is
[`agents/README.md`](./agents/README.md).

```
product owner ── talks only to Ideas
 └─ Ideas (chat, hub worktree «Ideas») ── its own Run: an inbox
     └─ Run-to-Run mail, never a worker relation
         └─ Tech-lead (chat, hub worktree «Tech-lead») ── its own standing Run
              ├─ workers, one per work unit (worker-start --worktree new-child)
              ├─ PR monitor        → the Tech-lead's Run mailbox
              └─ permission watch  → the Tech-lead's Run mailbox
Shared memory: one Engram project, read and written by both chats
```

## How they talk

Each coordinator owns one Orca **Run**, which is its mailbox. Its id lives in a file:
`~/.local/share/<stack.id>-ideas/run-id.txt` for Ideas and `~/.local/share/<stack.id>-tech-lead/run-id.txt` for the
Tech-lead. A message goes to the peer's Run:

```bash
orca orchestration send --to "run:$(cat ~/.local/share/acme-tech-lead/run-id.txt)" --type status \
  --subject "[From Ideas] <subject>" --body "$(cat <file>)"
```

- The body is written to a file first and passed with `"$(cat <file>)"`, so the shell never expands its content.
- Subjects start with `[From Ideas]` or `[Tech-lead]`. The monitors use `[PR monitor]` and `[Worker watch]`.
- Each chat keeps one mailbox wait armed in the background,
  `orca orchestration check --run <own run id> --wait --timeout-ms 1800000 --json`, with a Bash timeout above it,
  and acknowledges and re-arms it after every delivery. Orca also nudges an idle chat bound to a Run when new mail
  arrives; that covers a wait that ended or was killed, but it is the fallback, not the rule.
- Nobody types into another agent's terminal or chat.
- Workers reach the Tech-lead through its Run, with `worker_done`, `ask`, `escalation` and heartbeats.

The full protocol is in [`docs/setup-guide.md`](./docs/setup-guide.md#the-mailbox-protocol).

## Prerequisites

Versions marked «tested» are the ones this setup was written and checked against; older ones may work but were not
checked.

| Need | Version | Check | Notes |
| --- | --- | --- | --- |
| Orca desktop app and its `orca` CLI | **≥ 1.4.245** | `orca --version` | Chat UI on, «Agent sleep» off, «Agent Dashboard» on ([setup guide](./docs/setup-guide.md#orca-settings)) |
| Claude Code | 2.1.314 tested | `claude --version` | Logged in. Ideas, the Tech-lead and the workers are Claude Code sessions |
| `git` | 2.55.0 tested | `git --version` | Local clones of every repository in the config |
| GitHub CLI `gh` | 2.100.0 tested | `gh --version`; `gh auth status` | Logged in, with access to every repository in the config. The PR monitor uses it |
| `tmux` | 3.7c tested | `tmux -V` | The two monitors run in detached tmux sessions |
| `jq` | 1.8.1 tested | `jq --version` | The tools and the bootstrap read Orca's JSON output with it |
| `yq` (mikefarah, Go) | v4 | `yq --version` | The config parser `tools/load-config.sh` uses. The minimum v4 release is in [`tools/README.md`](./tools/README.md) `(unverified here)` |
| Engram, registered as Claude Code's MCP server | 3.4.0 tested | `engram version`; `claude mcp list` | The shared memory of both chats ([setup guide](./docs/setup-guide.md#engram)) |
| gentle-ai | 4.2.0 tested, **optional** | `gentle-ai --version` | Not required. When installed, the workflow's rules take precedence over it ([delivery model](./docs/delivery-model.md#when-gentle-ai-is-installed)) |

The tools also need `bash` and the GNU core utilities; [`tools/README.md`](./tools/README.md) lists them.

## Quick start

1. Clone this repository (or your fork of it) outside your product repositories:

   ```bash
   git clone https://github.com/<owner>/orca-agent-team.git
   cd orca-agent-team
   ```

2. Copy the example config and fill it for your stack:

   ```bash
   cp config/stack.example.yaml config/stack.yaml
   ```

   `config/stack.yaml` is your local copy; keep it out of commits if your repository names are private.

3. In the Orca app, set Chat UI on, «Agent sleep» off and «Agent Dashboard» on.
4. Open a Claude Code chat in Orca on this repository's checkout, and give it this prompt:

   ```text
   Read BOOTSTRAP_PROMPT.md in this repository whole, then execute it step by step against config/stack.yaml.
   Stop at every step marked HUMAN and tell me exactly what to do in the Orca UI.
   ```

5. Follow the steps it hands you. At the end, the Ideas chat and the Tech-lead chat are open in the hub
   repository, both Runs exist, the monitors run, and one message has gone Ideas → Tech-lead → Ideas.
6. Talk to Ideas.

After a reboot, follow [`docs/reboot.md`](./docs/reboot.md).

## Configuring the stack

Everything stack-specific lives in `config/stack.yaml`. The commented example is
[`config/stack.example.yaml`](./config/stack.example.yaml); it uses a made-up stack called «acme».

| Section | What it sets |
| --- | --- |
| `stack` | `id` (lowercase, digits and dashes) drives every local path, such as `~/.local/share/<id>-ideas/`; `name` is for display |
| `repos[]` | Every repository of the stack: Orca name, local path, GitHub `owner/repo`, main branch and `kind`. Exactly one repository is the `hub`, where Ideas and the Tech-lead live and the PRDs, ADRs and backlog are kept. The other kinds (`frontend`, `backend`, `docs`, `infra`, `other`) pick the developer role card |
| `memory` | The Engram project key every chat uses, and the topic prefix |
| `language` | The language of the conversation with the product owner, of artifacts, and of app copy, plus free-form app-copy rules |
| `models` | Model and effort for Ideas, the Tech-lead and each worker seniority |
| `orca` | The Orca settings the setup expects, and the monitors' notify mode (`run` by default) |
| `monitors` | Poll intervals, the PR author filter and the merged-PR window |

`tools/load-config.sh` reads the YAML and writes a shell-sourceable env file, by default
`~/.local/share/<id>/stack.env`, which the monitors source. See [`tools/README.md`](./tools/README.md).

After a change to `config/stack.yaml`, run `tools/load-config.sh` again and restart the monitors. A new repository
also needs `orca repo add` ([setup guide](./docs/setup-guide.md#register-the-repositories)).

## Repository map

| Path | Holds |
| --- | --- |
| [`BOOTSTRAP_PROMPT.md`](./BOOTSTRAP_PROMPT.md) | The prompt an AI executes to bring the team up |
| [`config/stack.example.yaml`](./config/stack.example.yaml) | The configuration section, commented |
| [`agents/README.md`](./agents/README.md) | The operating manual: lifecycle, roles, delivery, links to every card and template |
| [`agents/team-conventions.md`](./agents/team-conventions.md) | Rules for everything an agent writes |
| [`agents/roles/`](./agents/roles/) | One card per role |
| [`agents/templates/`](./agents/templates/) | PRD, brief, worker report, test plan, and the after-start checklists of [Ideas](./agents/templates/after-start-ideas.md) and the [Tech-lead](./agents/templates/after-start-tech-lead.md) |
| [`tools/`](./tools/README.md) | The config loader, the PR monitor and the permission watch |
| [`docs/setup-guide.md`](./docs/setup-guide.md) | The setup guide, step by step, with the reasons |
| [`docs/reboot.md`](./docs/reboot.md) | What to do after a reboot or when a chat is reopened |
| [`docs/gotchas.md`](./docs/gotchas.md) | Known gotchas of Orca and Claude Code in this setup |
| [`docs/delivery-model.md`](./docs/delivery-model.md) | Integration branches, work-unit PRs, and who merges what |

## Maintaining this repository

- **Keep it generic.** No real product, company, repository, person, URL, id or local path in any file, commit or
  example. Examples use the «acme» stack, and people are named by role: «the product owner», «the Tech-lead».
- **Work like the team does.** Changes go through pull requests, with Conventional Commits in English and no AI
  attribution lines.
- **Re-verify Orca commands on every Orca upgrade.** Check each `orca` command in the docs against
  `orca <command> --help` and `orca skills get orchestration --full`, and update the minimum version in
  [Prerequisites](#prerequisites). Anything not re-run is marked `(unverified)`.
- **A new gotcha** goes in [`docs/gotchas.md`](./docs/gotchas.md) only once it is reproduced, with how to detect it
  and the workaround.
- **A new repository kind** needs a role card in [`agents/roles/`](./agents/roles/), its `kind` in the config
  example, and a row in [`agents/README.md`](./agents/README.md).
- CI runs shellcheck on `tools/*.sh` and a Markdown link check ([`.github/workflows/ci.yml`](./.github/workflows/ci.yml)).

## License

[MIT](./LICENSE).
