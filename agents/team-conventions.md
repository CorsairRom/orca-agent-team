# Team conventions

The general rules every agent of the team applies to everything it writes, in any repository of the stack: Orca
workers, the tech lead, Ideas, and any chat opened in a repository of the stack. A brief or a role card can add a
role-specific detail; it never relaxes a rule here.

This file holds only what any team needs. A team's own rules go in the `conventions:` list of the stack's
configuration, `config/stack.yaml` ([example](../config/stack.example.yaml)); the tech lead copies them into the
"Team conventions" section of every brief, and they apply like the rules below. A new project starts with none.

## Languages

The stack's configuration sets the languages, and every brief carries their values:

| Config key | What it decides |
| --- | --- |
| `language.owner_conversation` | The language Ideas and the tech lead use with the product owner |
| `language.artifacts` | The language of code, documentation, PR titles and bodies, and commit messages, unless the target repository uses another one |
| `language.app_copy` | The language of UI strings, manuals and any other text the product's users read |
| `language.app_copy_rules` | Free-form rules every writer of app copy applies, such as a register or forbidden forms |

- App and manual copy is written in `language.app_copy` and follows every rule in `language.app_copy_rules`.
- Copy describes what the product does, never why a change was requested or who asked for it.

## Each repository's own structure

- Follow the target repository's own instruction files (`CLAUDE.md`, `AGENTS.md`, contributing guides) and its
  existing layout. Where they say more than this file, they win for that repository.
- A repository's own rules on comments, formatting, tests, commit messages and PRs apply. When it has none, match
  the surrounding code and the structure of its recent merged PRs and commits.
- A PR body follows the repository's PR template, or, where it has none, the structure of its recent merged PRs.
  Each developer role card says how to find it.

## Files and scratch

- Briefs, messages, reports and PR bodies live in a durable folder, never under `/tmp`, which a reboot clears.
- Scratch files live outside every repository and are deleted after use.
- Never commit local tool state, dependency folders, env files, or a tool's side effects, such as a lock file
  rewritten by an install nobody asked for.

## Secrets

- Secrets, credentials and personal data never go into a brief, a message, a commit or a PR.

## Commands

- If a command needs approval and does not get it, skip it and say so; never wait on it, and never retry it in
  another shape to get around the denial.
- Prefer the editor tool over `sed -i` and command substitutions in shell commands; auto-mode permission checks may
  block them.
- Write bash-only syntax (indirect expansion, arrays, `[[ ]]`) inside `bash -c '...'`: the Bash tool runs the
  user's login shell, which may be zsh ([gotcha](../docs/gotchas.md#the-bash-tool-may-run-zsh)).
- `$(...)` and backticks inside a double-quoted `--body "..."` run in the shell. Write a message body to a file and
  pass it as `--body "$(cat <file>)"`.
