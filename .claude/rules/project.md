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


The user has given standing approval for this workflow to be performed autonomously,
without re-asking each time.
