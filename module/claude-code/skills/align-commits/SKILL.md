---
name: align-commits
description: Use when the user has already started an interactive rebase (`git rebase -i`) with one or more commits marked `edit` and wants each stopped commit's diff self-reviewed, refined, and its message rewritten to convention before advancing.
---

# align-commits

You polish a run of commits one at a time during an interactive rebase the USER already started. At each commit the user marked `edit`, you: adversarially self-review the diff, fold in any real improvements, rewrite the message to convention, verify the tree is clean, then advance. You never touch commits the user did not mark `edit`, and you never `git push`, force-push, `git rebase --abort`, or run any destructive reset unless the user explicitly asks.

## Precondition — the user starts the rebase, not you

A `git rebase -i` must be **already in progress**, stopped at a commit marked `edit`. Because git stops *after* applying an `edit` commit, that commit is already `HEAD` and the working tree is clean.

You do NOT start the rebase. If the user asks you to begin it, tell them to run `git rebase -i <base>` themselves, mark the commits they want polished as `edit`, then re-invoke you.

## Step 0 — Confirm the state before doing anything

Run `git status` and branch on what it reports:

- **Interactive rebase in progress, "currently editing a commit while rebasing", working tree clean** → this is the expected edit stop. Proceed to the loop.
- **No rebase in progress** → STOP. Tell the user to run `git rebase -i <base>`, mark each commit to align as `edit`, then re-invoke this skill. Do nothing else.
- **Rebase in progress but with unmerged paths** (a conflict stop, not an edit stop) → STOP. You are not at an editable commit; amending here is wrong. Point the user at "Handle a conflict" below.
- **Edit stop but the working tree is dirty** (unexpected staged/unstaged changes the user left behind) → STOP and ask how to handle them. Do not sweep stray changes into the commit.

## The loop — one `edit` commit per iteration

Repeat for each `edit` stop until the rebase finishes.

### 1. Read the stopped commit

`HEAD` is the stopped commit. Inspect it fully:

- `git show HEAD` — the complete diff and current message.
- `git show --stat HEAD` — the file-level shape.

### 2. Maximum-effort adversarial self-review of the DIFF

Review **this commit's diff in isolation**, as if it were a pull request you were determined to reject. Reason at maximum effort about:

- **Correctness** — off-by-ones, wrong conditions, missed edge/error cases, resource leaks, broken invariants, anything subtly wrong that the diff introduces.
- **Quality** — dead code, debug leftovers, needless complexity, poor naming, inconsistency with the surrounding code's conventions.
- **Completeness** — the diff references something it forgot to add or update.

For a large or high-stakes diff, you MAY dispatch an independent review subagent (via the Task/Agent tool) to review the same `git show HEAD` output and return a second opinion; fold its findings into yours. Do not rely on any tool you cannot actually call — if no subagent is available, do the full-depth review yourself.

Act only on concrete, defensible improvements. Do not churn the diff for taste.

### 3. Make and stage improvements (only if the review found real ones)

1. Edit the files in the working tree.
2. Stage **deliberately, file by file** — `git add <path>` per file, or `git add -p` for specific hunks. **Never** `git add -A` or `git add .`.
3. Do NOT commit yet — the single amend happens in step 4 so content and message land together.

If the review found nothing actionable, make no edits and carry the existing content into step 4 unchanged. If your edits would revert the commit's entire diff (leaving it empty), that is almost never what you want here — reconsider rather than deliberately emptying the commit.

### 4. Rewrite the message and fold in staged changes with a single amend

Craft the message so it accurately describes the commit's **current** content:

- **Conventional commits**: `type(scope): description` (`feat`, `fix`, `chore`, `ci`, `docs`, `refactor`, `test`, …). Match this repo's existing scope conventions.
- Written for **future developers** and the repo's own conventions. **No** conversational or session context — never "as we discussed", "per user request", "in this session", ticketless references, or anything about how the change came to be.
- Ends with the Co-Authored-By trailer naming the exact model you are running as. For an Opus 4.8 (1M context) agent that is:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- Contains **no** `Claude-Session:` trailer or any other session-identifying line. If the original message has one, drop it.

Then amend once:

```
git commit --amend
```

This folds any changes you staged in step 3 into the current commit **and** updates its message in one shot. Structure the message as subject, blank line, body, blank line, trailer at the very end — use the editor, or multiple `-m` flags (`git commit --amend -m "type(scope): subject" -m "body…" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"`), so the blank-line separators and the trailing trailer are correct. A single `-m "…"` with embedded newlines is error-prone — prefer the editor or multiple `-m`.

**This amend is the sanctioned exception to the "never amend" rule.** The user explicitly started this rebase for history cleanup and `HEAD` is the very commit being edited. (In normal work you would use a fixup commit instead — not here.) The only commit you ever amend is the one at the current `edit` stop.

If the existing message already fully complies (conventional, future-facing, correct exact-model trailer, no session line) **and** you staged nothing in step 3, you may skip the amend entirely and go straight to step 5.

### 5. Confirm the tree is clean, then advance

Run `git status`. Everything you intended must already be in the amended commit and the working tree must be clean — no stray staged or unstaged changes. (`git rebase --continue` refuses to run with staged changes, and unstaged changes can be dragged into or collide with the next pick.) If something stray remains, resolve it deliberately — stage the wanted hunks into another `git commit --amend`, or discard the unwanted ones — but never blanket-`git add`.

Once the commit is golden and the tree is clean:

```
git rebase --continue
```

### 6. Read the result and branch

Read what `git rebase --continue` **printed** (the "pick is now empty" notice appears here, not in `git status`), then run `git status`. Determine which of these happened:

- **Stopped at the next `edit` commit** — `git status` shows the rebase still in progress, "currently editing a commit while rebasing", clean tree. `HEAD` is now that next commit → go back to **step 1**.
- **Rebase finished** — `git status` shows a normal branch with no rebase in progress → stop looping and give the final report (below). Done.
- **Merge CONFLICT while replaying a later commit** — `git status` shows unmerged paths and "you are currently rebasing". Do **not** guess-resolve it, and do **not** `git rebase --skip` (that would silently drop the whole commit). See "Handle a conflict".
- **A replayed commit became empty** — the `git rebase --continue` output says the pick is now empty (its changes are already present, e.g. you folded them into an earlier commit). See "Handle an empty replayed commit".

**Handle a conflict.** Stop and tell the user a conflict occurred; do not resolve it blind as part of polishing. Orientation, because a rebase **inverts** the merge sides:

- `ours` / `HEAD` is the branch being rebased **onto** — the new base plus the commits already replayed. Inspect it with `git log` and `git show HEAD`.
- `theirs` is the commit currently being replayed. It is `git show REBASE_HEAD`.
- Compare against the merge base to understand the intended change.

After the user (or a dedicated conflict-resolution skill, if they have one) resolves it — staging the fixed files deliberately with `git add <path>`, never `git add -A`, then `git rebase --continue` — they should re-invoke this skill to continue polishing any remaining `edit` stops.

**Handle an empty replayed commit.** Follow git's printed instructions, confirming first with `git status` and `git show REBASE_HEAD`:

- To **drop** it (the usual case here — its content already lives in an earlier commit you edited): `git rebase --skip`.
- To **keep** it as an intentional empty commit: `git commit --allow-empty`, then `git rebase --continue`.

Then re-read the result with `git status` and route again through this step.

### Final report

When the rebase finishes, give a concise summary: which commits you amended, what content improvements you actually made, and which messages you rewrote (and why, when a message changed meaningfully).

## Hard constraints

- Only ever modify commits the user marked `edit`. Never reorder, squash, drop, or edit any other commit.
- The only amend you perform is on the commit at the current `edit` stop.
- **Never** `git add -A` or `git add .` — stage file by file or hunk by hunk.
- Never `git push`, force-push, `git rebase --abort`, or run any destructive reset unless the user explicitly asks. Never `git rebase --skip` a non-empty conflicted commit — that silently discards work.
- Every rewritten message ends with the exact-model Co-Authored-By trailer and contains no `Claude-Session:` or other session-identifying line.
- If the state ever fails to match what a step expects, STOP and ask rather than improvise.
