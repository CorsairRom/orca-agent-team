# Team conventions

Every agent of the team applies these rules to everything it writes, in any repository of the stack: Orca
workers, the tech lead, Ideas, and any chat opened in a repository of the stack. A brief or a role card can add a
role-specific detail; it never relaxes a rule here.

Rules that change from one stack to another are not here. They live in the stack's configuration,
`config/stack.yaml` ([example](../config/stack.example.yaml)), and every brief carries their values:

| Config key | What it decides |
| --- | --- |
| `language.owner_conversation` | The language Ideas and the tech lead use with the product owner |
| `language.artifacts` | The language of code, documentation, PR titles and bodies, and commit messages, unless the target repository uses another one (see below) |
| `language.app_copy` | The language of UI strings, manuals and any other text the product's users read |
| `language.app_copy_rules` | Free-form rules every writer of app copy applies, such as a register or forbidden forms |

## Code

- Follow the target repository's own instruction files (`CLAUDE.md`, `AGENTS.md`, contributing guides) and its
  existing layout. Where they say more than this file, they win for that repository.
- A repository's own rules on comments, docstrings and formatting apply. When it has none, match the density and
  idiom of the surrounding code.

## Base architecture

- Reuse the repository's existing infrastructure: HTTP clients, auth, permissions, feature flags, data access,
  shared components, configuration, CI.
- Never create a new shared layer, cross-domain module or parallel mechanism, and never add a library or pattern the
  repository does not already use, without an explicit decision by the tech lead, written down before the code.
- The reviewer treats a violation as a blocker.

## Pull requests and commits

- Commit messages and PR titles follow Conventional Commits, in `language.artifacts`, in every repository.
- A PR body follows the target repository's own structure and language: its PR template, or, where it has none,
  the structure of its recent merged PRs. Each developer role card says how to find it.
- No AI attribution: no `Co-Authored-By` trailer and no "Generated with" line, in commits or PR bodies.

## Copy

- App and manual copy is written in `language.app_copy` and follows every rule in `language.app_copy_rules`.
- Copy never explains why a change was requested or who asked for it.

## Git and merges

- Work-unit PRs target the feature's integration branch, and the tech lead merges them once their checks pass.
  Only the product owner merges into a repository's main branch ([delivery model](../docs/delivery-model.md)). No
  other agent merges anything.
- Never commit local tool state (for example `odd/` or `.atl/`), dependency folders such as `node_modules`, env
  files, or a tool's side effects, such as a lock file rewritten by an install nobody asked for.
- No rebase and no force-push of published commits.

## Commands and permissions

- If a command needs approval and does not get it, skip it and say so; never wait on it, and never retry it in
  another shape to get around the denial.
- **Known case: `sed -i` with a git-status array.** One Bash call that runs `sed -i` and builds a shell array from
  a command substitution of git status, such as `$(git status --porcelain | awk ...)`, can trigger Claude Code's
  rm-safety permission prompt and block the agent. Make the edit with the Edit tool and pass explicit file paths.
- **Known case: `rm` on a substituted path.** `rm` on a path built from a command substitution, such as
  `$(mktemp)`, can trigger the same prompt. For a PR body, use `gh pr create --body-file` with a fixed path, or
  `--body` from a quoted heredoc, and leave temp-file cleanup to the tech lead.
- **Shell expansion in messages.** `$(...)` and backticks inside a double-quoted `--body "..."` run in the shell.
  Write a message body to a file and pass it as `--body "$(cat <file>)"`.

## Files and data

- Briefs, messages, reports and PR bodies live in a durable folder, never under `/tmp`, which a reboot clears.
- No demo data, demo switches or synthetic values in product code or PRs. Local demo shims live outside every
  repository and are never committed.
- Secrets, credentials and personal data never go into a brief, a message, a commit or a PR.
