---
name: solve-conflicts
description: Use when a git rebase has halted on a merge conflict and you need to resolve the conflicts so the rebase can finish.
---

# Resolve rebase conflicts

You are driving an **in-progress `git rebase` that has HALTED on a merge conflict**. Your job: resolve each conflict so BOTH sides survive and stay functional, then let the rebase finish. Work the loop below until the rebase completes or you must stop for the user.

## Rebase mental model — read this first, it is inverted

During a rebase the sides are the OPPOSITE of a normal merge:

- **`ours` / `HEAD`** = the **new base** the branch is being replayed ONTO (commits already applied).
- **`theirs`** = the **commit currently being replayed**, i.e. `REBASE_HEAD`.

So a marker block
```
<<<<<<< HEAD
   (top = the new base / ours)
=======
   (bottom = the commit being applied / theirs)
>>>>>>> <hash>
```
means top is the new base, bottom is the replayed commit. Never blind-pick a side.

**Conflict stop ≠ edit stop — this changes what you may do:** at a CONFLICT stop the conflicting commit is **not committed yet**. `HEAD` is the *previous, already-applied* commit; the conflict lives in the working tree and index. You finish the commit by staging and running `git rebase --continue` (git recreates it, reusing its message). This is unlike an interactive `edit` stop, where `HEAD` already IS the stopped commit. Consequence: **never `git commit --amend` here** — it would rewrite the wrong (previous) commit.

## The loop

### 1. Confirm the state

Run `git status`.

- **No rebase in progress** → nothing to resolve. **Stop** and tell the user no halted rebase was found.
- **Unmerged paths from a non-rebase operation** (a plain `git merge`, standalone `git cherry-pick`, or `git stash` pop — `MERGE_HEAD`/`CHERRY_PICK_HEAD` present, no rebase) → **Stop**. This skill is rebase-scoped; the ours/theirs mapping above would mislabel those. Tell the user.
- **Rebase in progress but NO unmerged paths** (clean or fully-staged tree) → this is an interactive `edit`/`reword` stop, not a conflict → **Stop** and tell the user (out of scope for this skill; they may want the history-cleanup skill, or to `git rebase --continue`).
- **Rebase in progress WITH unmerged paths** (`both modified` / `Unmerged paths`) → note the paths and proceed.

Identify the commit being applied: `git show REBASE_HEAD` (or `git rebase --show-current-patch`).

### 2. Build a maximum-effort understanding of BOTH sides

Do NOT resolve until you genuinely understand both intents. This is the high-effort, adversarial step — reason carefully, do not pattern-match.

- **The commit being applied** (`theirs`): `git show REBASE_HEAD` — read its full diff and message. What is it changing and WHY? What behavior MUST survive?
- **The new base** (`ours` / `HEAD`): `git log --oneline -n 30 HEAD` — what already landed on the branch you are replaying onto.
- **The exact three versions git used**, per conflicted `<path>` (index stages are precise — no merge-base guesswork):
  - `git show :1:<path>` — common ancestor (base)
  - `git show :2:<path>` — **ours / new base** (HEAD)
  - `git show :3:<path>` — **theirs / commit being applied** (REBASE_HEAD)
  - To isolate each side's edit in that region: `git diff :1:<path> :2:<path>` (what the base changed) vs `git diff :1:<path> :3:<path>` (what the replayed commit changed).
- Read the conflicted file's actual markers.

Optionally, for a hard or high-risk conflict, **dispatch an independent review subagent** (via a Task/Agent-style tool, if one is available) to separately read `REBASE_HEAD`, the `:1`/`:2`/`:3` versions, and the hunks, and report its own reading of both intents. Treat it as a second opinion; you remain responsible for the resolution.

### 3. Resolve so BOTH intents survive

Edit each conflicted file so the new base's changes AND the replayed commit's purpose are BOTH preserved and the result is **functional** — correct, compiling, self-consistent code, not a mechanical concatenation. Remove every conflict marker (`<<<<<<<`, `=======`, `>>>>>>>`). Integrate; do not silently discard a side.

### 4. If the sides genuinely contradict — STOP

If the two intents truly cannot both be functional at once (they change the same behavior in mutually exclusive ways), do **not** guess and do **not** silently drop one side. Stop, explain the specific conflict of intent, and ask the user how to proceed.

### 5. Stage, sanity-check, continue

- Stage each resolved file **specifically**: `git add <path>` for every path you fixed. **Never** `git add -A` or `git add .`. If you deliberately resolved only some hunks of a file, stage precise hunks with `git add -p`.
- Sanity-check: `git diff --cached -- <path>` (and/or grep for `<<<<<<<`) to confirm no leftover markers and that the merged result reads correctly. Confirm `git status` shows **no** remaining `Unmerged paths`.
- If a compile/lint/format check is cheap and available, run it on the touched files.
- **Continue** — the routine case keeps the replayed commit's original message verbatim (including any trailers it already has). `git rebase --continue` reuses that message and opens an editor to confirm it; to keep it intact **without a hanging interactive editor**, run:
  ```
  GIT_EDITOR=true git rebase --continue
  ```
- **Do NOT `git commit --amend`** — at a conflict stop that rewrites the previous, already-applied commit, not the one you resolved. The replayed commit's message is shaped only through the editor `git rebase --continue` opens.
- **If you have a genuine reason to change the replayed commit's message**, do it in that editor (drop `GIT_EDITOR=true`, or point `GIT_EDITOR` at your text): keep or add the exact-model trailer naming the model doing the work — for this model `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` — do **not** strip a trailer the original message already carries, add **no** `Claude-Session:` line or any session-identifying trailer, and write for future developers and the repo's conventions (never the conversation, "as we discussed", or "per user request").
- **Empty commit:** if your resolution makes the replayed commit's changes identical to what the new base already has, the commit becomes empty. Behavior on `git rebase --continue` is version/config dependent: recent git silently **drops** it and moves on; older git (or `--empty=stop`/`ask`) instead **halts and prints instructions** (`git rebase --skip` to drop, or `git commit --allow-empty` then `git rebase --continue` to keep). **Read git's actual output and follow it.** If a commit you meant to keep got dropped (or one that should have been dropped survived), tell the user rather than papering over it; if unsure whether it should remain in history, ask.

### 6. Re-check and repeat

Run `git status` again and branch on the state (same as step 1):

- **New unmerged paths** (rebase still in progress) → go back to step 1 and resolve the next conflict the same way.
- **Rebase in progress but clean / no unmerged paths** → git advanced to an interactive `edit`/`reword` stop → out of scope → **stop** and tell the user.
- **Rebase finished** (no rebase in progress) → report a concise summary: which commits conflicted, how you reconciled each, and any file where you made a judgment call. Then stop.

## Hard rules

- Never run `git rebase --abort`, `git reset --hard`, or any destructive/history-discarding command, and never drop one side of a conflict, unless the user explicitly asks.
- Never `git commit --amend` during conflict resolution — at a conflict stop it rewrites the wrong commit.
- Never stage with `git add -A` / `git add .` — always `git add <path>` or `git add -p`.
- Commit-message rules (only when you actually write or adjust a message): end with the exact-model `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`; never add a `Claude-Session:` or other session-identifying trailer; address future developers and repo conventions, never the conversation.
- When genuinely in doubt about intent, or facing a real contradiction, stop and ask rather than guessing.
