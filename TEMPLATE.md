# The KofTwentyTwo Windows app template

This repository is a complete, working WinUI 3 app ("Kof22 App") **and** a `dotnet new`
template that turns it into a new app with your names. The starter provides the code and quality gates used by the [KofTwentyTwo standards](https://github.com/KofTwentyTwo/standards): the AppKit shell, a 100%-covered core, FlaUI UI tests, Kingsrook-style quality gates,
repository files, and the shared CI, security, and release workflows. It implements the
[Windows desktop reference architecture](https://github.com/KofTwentyTwo/standards/blob/main/architecture/windows-desktop-app.md).

This file is not copied into generated apps.

## Create an app

```powershell
# Install the template from a clone of this repository (or, once published, from NuGet)
dotnet new install .

# Generate
dotnet new k22-winapp -n Contoso.Notes --appId contoso-notes --displayName "Contoso Notes" `
   --description "Quick notes that stay out of the way." -o Contoso.Notes
```

To try the installable package before its first publication, run from this clone:

```powershell
dotnet pack templates/KofTwentyTwo.Templates.WindowsApp.csproj -c Release -p:Version=0.1.0 -p:RestoreLockedMode=true -o artifacts/template
dotnet new install ./artifacts/template/KofTwentyTwo.Templates.WindowsApp.0.1.0.nupkg
dotnet new k22-winapp -n Contoso.Notes --appId contoso-notes --displayName "Contoso Notes" -o artifacts/Contoso.Notes
# Add --cli false for a GUI-only app; use a fresh output directory each time.
```

| Option | Default | What it sets |
| --- | --- | --- |
| `-n`, `--name` | (required) | Solution, project, namespace, and executable names (`Contoso.Notes.slnx`, `Contoso.Notes.Core`, `Contoso.Notes.exe`), and the repository name in links |
| `--appId` | (required) | Machine id: data folder `%LOCALAPPDATA%\<appId>`, its override variable, log files, credential prefix, CLI executable, Velopack package id. Lowercase letters, digits, dashes. Never change it after the first release |
| `--displayName` | (required) | Product name in the title bar, splash, About, menus, and docs |
| `--description` | "A KofTwentyTwo Windows desktop application." | One sentence for the README, About, and main window |
| `--authorName` | James Maes | Copyright holder in license headers, LICENSE, and credits |
| `--owner` | KofTwentyTwo | GitHub owner in repository links, CODEOWNERS, and badges |
| `--cli` | true | Include the command-line head and its tests (`--cli false` to leave them out) |

The copyright year in license headers becomes the current year.

## After generating

The generator omits NuGet dependency lock files. Before the first commit, run
`dotnet restore <name>.slnx -p:Platform=x64` in the generated directory to create
them, then run the README's locked restore, build, test, coverage and format
commands. Commit the resulting
`packages.lock.json` files. Install the included hooks with
`pre-commit install --hook-type pre-commit --hook-type commit-msg` after `git init`.
The generated PowerShell tooling gate uses PSScriptAnalyzer 1.25.0.

1. Follow [the preview/apply/validate setup runbook](docs/repository-setup.md).
   Create the GitHub repository (public, Product tier), push `main`, and apply the
   [repository standard's](https://github.com/KofTwentyTwo/standards/blob/main/standards/repository.md)
   settings and rulesets. Use the setup tool's required contexts and
   [CONTRIBUTING.md](CONTRIBUTING.md)'s check table; standalone job names have no
   workflow-name prefix. The source repository additionally requires `template`;
   generated application repositories do not.
2. Create the `release` environment limited to `v*` tags, and list the repository in the
   [standards repository inventory](https://github.com/KofTwentyTwo/standards/blob/main/MAINTAINERS.md#repositories)
   (`K22-REPO-42`; the conformance checker fails until it is listed).
3. Replace the brand mark: `dotnet run --project <AppKit>/tools/BrandTool -- --out src/<name>/Assets/Brand --start "#RRGGBB" --end "#RRGGBB" --glyph "<svg path data>"`.
4. Replace the example greeting feature with the app's real one; keep the shape (logic and
   view model in Core with tests, a thin view in the WinUI project).
5. Update `docs/security/threat-model.md` for the app's real attack surface, and run
   `pwsh <standards>/tools/Test-RepoConformance.ps1 -Repository <owner>/<name> -LocalPath .`.
6. Follow [docs/RELEASING.md](docs/RELEASING.md), including the pending steps.

## Maintaining the template

The template is the app: change it like any app (topic branch, pull request, all gates),
then check that it still generates cleanly:

```powershell
dotnet new install . --force
dotnet new k22-winapp -n Smoke.App --appId smoke-app --displayName "Smoke App" -o ..\smoke
dotnet new k22-winapp -n Smoke.NoCli --appId smoke-nocli --displayName "Smoke NoCli" --cli false -o ..\smoke-nocli
dotnet new uninstall .
```

Placeholders the template replaces, so keep them exactly as written in the source:
`Kof22App` (the name), `kof22-app` (the app id), `Kof22 App` (the display name),
`A KofTwentyTwo Windows desktop application.` (the description), `James Maes` (the
author), `KofTwentyTwo/windows-app-template` (the owner and repository, which becomes `<owner>/<name>`) and `@KofTwentyTwo` (the owner), and `2026` after
`Copyright (c)` followed by a space (the year). Content that only applies with the command line is in
`<!--#if (cli) -->` blocks (Markdown, XML) or in the app workflow copies under `.template.config/with-cli/` and `.template.config/no-cli/`.

`templates/KofTwentyTwo.Templates.WindowsApp.csproj` packs the template as a NuGet
package (`dotnet pack templates/KofTwentyTwo.Templates.WindowsApp.csproj`).

## Publishing this template

This source repository publishes `KofTwentyTwo.Templates.WindowsApp` on protected
`v*` tags using the shared NuGet builder. Generated applications use separate
Velopack workflows with stable/dev channels. Source CI installs the packed template
and exercises both CLI variants, including build, format, coverage and UI tests.

Before the first publication, configure the protected repository and release
settings, register it in the standards inventory, and set `NUGET_USER`. The owner
must save a NuGet trusted-publishing policy for owner `KofTwentyTwo`, repository
`windows-app-template`, workflow `release.yml`, environment `release`, and package
`KofTwentyTwo.Templates.WindowsApp`. Publication is pending until these steps and
live CI/attestation verification are complete. Do not claim certification from
successful local tests.
