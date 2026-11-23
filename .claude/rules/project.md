# Godot tech test game project

Project-specific instructions. General Godot practices are in `.claude/CLAUDE.md`.

## Project Goal
This project is to reverse engineer the game stree trash 3 and redo it in Godot.

Information about this game are at:
- https://www.youtube.com/watch?v=q4IzdXGOfOs
- https://gta.wiki/w/Street_Trash_III%3A_Dezombifier
- https://nerdschalk.com/street-trash-iii-dezombifier-choose-perks/


All the art and audio assets can be placeholder. The focus is that the gameplay is implemented as in the original game and it can be played.

Implement the game yourself following the principles defined in thsi project, test the game to check that everything is working.
Always keep testing time short, and focus on testing that each feature is implemented correctly rather than always playing the entire game. IDeally every test should not last more than 30 seconds.

Iterate until done, following vertical slices principle so I can test after each slice. Find the list of al the perks online using ddg mcp server if you cannot find it in the provided resources. Keep focus on a single level and single main character for first slice, and max 20 perks implemented




## Development Principles

- This game is done in Godot. Godot exe available at "D:\Programs\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" (the `_console.exe` next to it prints to the terminal and is the one to use from scripts)
- This is a research project, no production-quality code
- Refactoring is always done by AI and it is cheap
- Code does not need to be retrocompatible, breaking changes are acceptable
- Given a directive, continue until you are completely confident that it has been fully and correctly implemented
- godot mcp server available and connected to use

## Decision and Requirement Records (arkouda)

The `arkouda` binary lives locally at `tools/arkouda/arkouda.exe` (gitignored)
and is **not** on `PATH`. Invoke it by that relative/local path (e.g.
`tools/arkouda/arkouda.exe list`) rather than assuming a bare `arkouda`
command resolves.

Use the `arkouda` tool, via the `use-arkouda` skill, as needed and exactly as
that skill instructs, every time development work happens in this repo:

- Before committing to a non-trivial design decision (a library, datastore,
  transport, schema/layout change, naming convention, or trade-off), check
  whether it's already been decided (`arkouda list`, `arkouda section`), and
  if not, capture the new decision as an ADR (`arkouda new`) once made.
- Before starting non-trivial feature work, check whether a PRD already
  defines its scope and non-goals.
- Run `arkouda check` after scaffolding or editing any ADR/PRD to keep the
  collection valid.

This applies on every branch/slice of work, not just when explicitly asked.

Always keep at the root readme.MD a table with the history of arkouda decisions and their corresponding ADRs description title.

## Git Workflow

Standing process for every change:

1. For every slice make a merge request, then you can approve and merge to main yourself
2. **Every PR targets `main`, never another feature branch.** Do not stack PRs: a PR whose base is another slice branch lands
   in that branch, and if that branch was already merged the work never reaches `main` (this happened with slice 7, which was
   merged into the already-merged `slice-6-hq-assets` and had to be re-opened). If a slice depends on an unmerged one, either
   merge the first PR before opening the second, or branch from the first and open the second PR against `main` only after the
   first has merged. After merging, check that the work is on `main` (`git fetch && git merge-base --is-ancestor origin/<branch> origin/main`)
   and that the PR's base was `main` before reporting it done.


The user has given standing approval for this workflow to be performed autonomously,
without re-asking each time.

### Parallel sessions: one worktree per session

Several Claude sessions can work on this repository at the same time. They must never share a working tree: a shared
tree means one checked-out branch, one set of uncommitted files and one Godot import cache for everybody.

1. **Start in a worktree.** Before the first edit, check whether the session is in a linked worktree:
   `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir` there, and equals it in the main checkout.
   If this session is in the main checkout, first create a worktree and work only inside it: use the `EnterWorktree`
   tool, or `git fetch origin && git worktree add ../street-garbage-4-<topic> -b <branch> origin/main` and `cd` into it.
   Read-only questions do not need one.
2. **One worktree, one branch, one slice.** Branches are `slice-N-<name>` (or `fix-<name>` for a fix).
3. **Never touch what is not yours.** Do not switch branches, reset, clean, stash or `git checkout --` in the main checkout or
   in another session's worktree. Never discard uncommitted changes in files this session did not write: they belong to the
   owner or to another session. Revert only files you can show you changed. Godot rewrites `.tres`/`.tscn` files with
   `uid=` entries when it imports, so run it, and look at `git status`, only inside your own worktree.
4. **Local-only files live in the main checkout.** `tools/arkouda/arkouda.exe`, `tools/level_gen/*.awk`, `art/concept art/`
   and the `.godot` cache are gitignored, so a new worktree does not have them. Call the tools by absolute path from the
   worktree (for example `D:/git_repos/street-garbage-4/tools/arkouda/arkouda.exe`). Edit a shared local file such as the
   level generator in place only if no other session is using it, and say so in the hand-over.
5. **Import once per worktree.** A new worktree has no import cache: run `godot --headless --path . --import` before the first
   test or export, and run tests and builds from inside the worktree.
6. **Finish cleanly.** Merge through a pull request as above, then `git worktree remove ../street-garbage-4-<topic>` and
   delete the branch. Base new worktrees on `origin/main` after a fetch, since the main checkout's `main` can lag.
