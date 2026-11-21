---
type: Architecture Decision Record
title: One git worktree per Claude session
description: Every Claude session works in its own linked git worktree on its own branch, never in the shared main checkout, so parallel sessions cannot overwrite each other's files, branch or Godot import cache.
tags: [process, git]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T17:27:21Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# One git worktree per Claude session

## Status

Accepted

## Context

Up to three Claude sessions work on this repository at once, plus the owner's Godot editor. Until now they mostly shared the
main checkout, each on its own branch. That caused real problems: switching branches under another session, an uncommitted
camera edit by the owner discarded during a cleanup, Godot import runs rewriting unrelated `.tres` files with `uid=` entries,
and sessions fighting over one `.godot` cache. The project instructions only said to make a pull request per slice.

## Decision

Every Claude session that edits files works in its own linked git worktree on its own branch, created before the first edit
if the session started in the main checkout. The rules (how to detect it, naming, what never to touch, local-only files,
import per worktree, cleanup) are written in `.claude/rules/project.md` under "Parallel sessions". The main checkout belongs
to the owner and their editor.

## Consequences

- Sessions cannot overwrite each other's files, branch or import cache, and the owner's editor stays undisturbed.
- Each new worktree needs a first `godot --headless --import` (about a minute) and has no gitignored local files, so tools
  such as arkouda are called by absolute path from the main checkout.
- Disk use grows with each worktree (its own `.godot` cache and imported art).
- Gitignored shared files (the level generator) are still single copies: a session edits them in place only when no other
  session is using them.
