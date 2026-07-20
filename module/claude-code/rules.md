# Working rules

User-level rules Claude Code applies in every repository. Project `CLAUDE.md`
files and explicit instructions still take precedence.

## Git — preserve work continuously

- **Back up work with git commits.** Commit at every meaningful checkpoint so no
  work survives only in the working tree. Prefer several small commits over one
  large one.
- **Stage deliberately — never `git add -A` or `git add .`.** Add changes file
  by file (`git add <path>`), and when a file mixes concerns stage specific
  hunks (`git add -p`). Only ever stage the specific changes you mean to commit;
  never blanket-stage the whole working tree.
- **Never amend during normal work.** `git commit --amend` rewrites an existing
  commit and destroys the backup it represents. The **only** exception is an
  interactive rebase you were explicitly asked to run for history cleanup (e.g.
  the `/align-commits` workflow), where amending the stopped `edit` commit is
  the intended operation.
- **Always use fixup commits.** To correct or extend an earlier commit during
  normal work, record a new `git commit --fixup=<sha>` instead of amending; fold
  the fixups in later only via an explicit interactive rebase you were asked to
  run.
- **Stamp every commit with the exact model.** End each commit message with a
  `Co-Authored-By:` trailer naming the exact model doing the work, e.g.
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Never add a `Claude-Session:` trailer** — or any other session-identifying
  line — to commit messages.
- **Confirm before destructive or history-rewriting git.** Stop and get explicit
  confirmation before `git push --force`/`--force-with-lease`, `git reset --hard`,
  `git clean -fd`, `git rebase --abort`, `git branch -D`, or anything else that
  discards commits or working-tree changes. These are the other ways work
  silently disappears.

## Secrets

- **Never stage or commit secrets** — `.env` files, private keys, tokens,
  passwords, or credentials of any kind. If a change needs a secret, reference it
  from the environment or a secret store; never hard-code it.

## Bugs — root cause, not symptom

- **Fix the root cause, not the symptom.** Do not paper over a failure with a
  retry, a broadened `catch`, or a special-case guard until you understand *why*
  it happens.
- **Start every bug fix with a reproduction.** Write a failing test (or a minimal
  repro) that captures the bug first, then make it pass — so the fix is proven and
  the regression can't return unnoticed.
