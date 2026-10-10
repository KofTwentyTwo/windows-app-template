# Kof22 App

A KofTwentyTwo Windows desktop app (WinUI 3, .NET 10) built on the KofTwentyTwo AppKit
packages, following the KofTwentyTwo standards (github.com/KofTwentyTwo/standards) and
its Windows desktop reference architecture.

## Commands

```powershell
dotnet restore Kof22App.slnx -p:Platform=x64 --locked-mode
dotnet build Kof22App.slnx -p:Platform=x64 -warnaserror
dotnet test Kof22App.slnx -p:Platform=x64 --no-build --filter "FullyQualifiedName!~UiTests" --settings coverage.runsettings --collect:"XPlat Code Coverage" --results-directory TestResults
./build/Assert-Coverage.ps1 -ResultsDirectory TestResults
dotnet test tests/Kof22App.UiTests --no-build      # launches the app on the desktop
dotnet format Kof22App.slnx --verify-no-changes --severity warn --no-restore
```

## Rules

- GitHub Flow: topic branch `<type>/<desc>` → PR to `main` → squash merge. Conventional
  Commit titles, `git commit -S -s` (signature and DCO). Agents never merge, tag, release,
  or change repository settings.
- `src/Kof22App` holds views and WinUI plumbing only. Logic, view models, and settings go
  in `src/Kof22App.Core`, held to 100% line coverage. Shell features (splash, About, log
  window, updates, theme, crash net) come from AppKit; do not re-implement them here.
- Zero warnings. Kingsrook style (`.editorconfig`): 3-space indent, Allman braces, `if(`,
  LF, three blank lines between members, a `///` header comment on every type and method,
  SPDX header on every file, one type per file.
- Package versions only in `Directory.Packages.props`; commit regenerated
  `packages.lock.json` files; CI restores in locked mode.
- Attack-surface changes update `docs/security/threat-model.md`; expensive-to-reverse
  decisions get an ADR in `docs/adr/`.
- The app id `kof22-app` names the data folder, logs, credentials, and Velopack package;
  never change it after the first release (installed copies would lose their data and
  updates).

- Significant AI contributions include a model-naming Co-Authored-By trailer and PR disclosure (K22-AGENT-40 / K22-AI-02).
