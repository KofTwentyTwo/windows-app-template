# ADR-0001: Adopt the KofTwentyTwo Windows desktop reference architecture

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

Kof22 App is a Windows desktop application. KofTwentyTwo publishes a
[reference architecture for Windows desktop applications](https://github.com/KofTwentyTwo/standards/blob/main/architecture/windows-desktop-app.md)
and an app template that implements it, proven in gclo 1.0 and factored into the
KofTwentyTwo AppKit packages. Building the shell (startup, updates, logging, settings,
credentials, crash handling, release pipeline) from scratch would repeat that work and
miss the standards' controls.

## Options considered

### Option A: start from the KofTwentyTwo Windows app template

- Pros: compliant with the KofTwentyTwo standards from the first commit; AppKit supplies
  the shell; the release pipeline is the shared SLSA Build L3 workflow.
- Cons: depends on AppKit's release cadence for shell changes.

### Option B: a hand-built WinUI app

- Pros: no external dependency for the shell.
- Cons: every shell feature, test, and pipeline control re-implemented and maintained
  here.

## Decision

Option A. The app follows the reference architecture: a WinUI 3 shell project with no
logic, a UI-free `Kof22App.Core` held to 100% line coverage, an optional command line over
the same core, FlaUI end-to-end tests, Velopack per-user install and self-update from
GitHub Releases, and the shared KofTwentyTwo workflows for every gate and release.

## Consequences

- Shell behavior (splash, About, activity log, updates, theme, crash net) changes by
  updating the AppKit packages, not by editing this repository.
- A departure from the reference architecture needs its own ADR here.
- The threat model starts from the reference architecture's common threats
  ([docs/security/threat-model.md](../security/threat-model.md)).
