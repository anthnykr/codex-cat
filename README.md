# Codex Cat

A small open-source macOS companion app for a pixel cat that walks around Codex.
The native app uses a transparent overlay so the cat can float above Codex
without blocking clicks.

https://github.com/user-attachments/assets/57c01192-d4dd-4314-99de-d61717879289

## Local Development

### Web Movement Harness

The web harness is only for testing movement and edge collisions without running
the native macOS app.

```bash
npm install
npm run dev
```

### Native macOS Menu Bar App

```bash
swift run CodexCat
```

The native app adds a `Cat` menu bar item and a transparent always-on-top overlay
window. The pixel cat bounces around the screen while ignoring mouse events, so
it can float above Codex without blocking clicks. By default, the overlay is only
visible while Codex is the focused app.

To create a local `.app` bundle:

```bash
chmod +x scripts/build-macos-app.sh
./scripts/build-macos-app.sh
open "build/macos/Codex Cat.app"
```

## Current Behavior

- Walks around Codex in a transparent click-through overlay.
- Only appears when Codex is focused, with an `Always Show` menu toggle for
  testing.
- Bounces off every edge of the overlay.
- Flips based on horizontal direction.
- Uses a transparent 4-frame pixel cat sprite sheet.

## Why This Is Separate

This repo builds a standalone companion app. It does not modify or inject code
into Codex.
