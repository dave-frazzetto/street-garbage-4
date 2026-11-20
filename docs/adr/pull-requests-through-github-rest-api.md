---
type: Architecture Decision Record
title: Pull requests through GitHub REST API
description: Without gh installed, slice PRs are opened and merged via the GitHub REST API using the Git Credential Manager token.
tags: [process]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:41Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Pull requests through GitHub REST API

## Status

Accepted

## Context

The workflow requires a merge request per slice, which the agent approves and merges itself. The `gh` CLI is not
installed on the development machine, but Git Credential Manager holds a GitHub token for the remote.

## Decision

Each slice is developed on a branch `slice-N-<name>`, pushed, and a PR is opened with `POST /repos/{owner}/{repo}/pulls`
and merged with `PUT /repos/{owner}/{repo}/pulls/{n}/merge` (merge commit). The token comes from
`git credential fill` and is never written to disk or logged.

## Consequences

- The process works without extra tooling. If `gh` gets installed later, use it instead.
- GitHub does not allow the PR author to approve their own PR, so the "approval" is the merge itself.
