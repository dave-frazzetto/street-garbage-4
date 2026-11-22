---
type: Architecture Decision Record
title: Custom web page shell with fullscreen button for mobile
description: Use a custom Godot HTML shell that pins the canvas to the dynamic viewport and adds a fullscreen button, so mobile browsers show no black band.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T08:56:57Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Custom web page shell with fullscreen button for mobile

## Status

Accepted

## Context

On phones the default Godot page left a black band under the canvas (the canvas keeps the size measured at load while browser bars and safe areas change), and there was no way to hide the Chrome/Safari bars. Fullscreen API is available on Android and desktop but not on iPhone Safari, and itch.io embeds the game in an iframe.

## Decision

Export with a custom HTML shell, `web/shell.html` (Web preset `html/custom_html_shell`). It sets `viewport-fit=cover`, fixes the body, pins the canvas to `100dvh`/`100dvw`, and fires a resize on visualViewport/orientation changes. It adds a Fullscreen button (Fullscreen API plus landscape lock where supported); on iPhone it shows Add to Home Screen instructions, and the page carries the iOS standalone meta tags. A PWA/service worker was rejected: caching stale builds is a worse trade for a fast-iterating game.

## Consequences

- The shell is a copy of Godot's template and must be re-synced if the engine template changes in a later Godot version.
- True fullscreen on iPhone needs the Home Screen install and the direct page, not the itch.io frame.
- Not yet verified on a physical phone.
