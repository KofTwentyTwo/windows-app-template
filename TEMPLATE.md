# The KofTwentyTwo Windows app template

This repository is a complete, working WinUI 3 app ("Kof22 App") **and** a `dotnet new`
template that turns it into a new app with your names. Everything a generated app needs
to meet the [KofTwentyTwo standards](https://github.com/KofTwentyTwo/standards) is already
here: the AppKit shell, a 100%-covered core, FlaUI UI tests, Kingsrook-style quality gates,
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

1. Create the GitHub repository (public, Product tier), push `main`, and apply the
   [repository standard's](https://github.com/KofTwentyTwo/standards/blob/main/standards/repository.md)
   settings and rulesets, with these required checks: `pr / title`, `pr / dco`,
   `pr / dependency-review`, `security / secrets`, `security / sca`,
   `security / workflows`, `codeql / analyze (csharp)`, `codeql / analyze (actions)`,
   `ci / build-test`, `ci / format`, `ci / ui-tests`.
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
`Copyright (c) ` (the year). Content that only applies with the command line is in
`<!--#if (cli) -->` blocks (Markdown, XML) or in the no-CLI copies of `ci.yml` and
`release.yml` under `.template.config/no-cli/`.

`templates/KofTwentyTwo.Templates.WindowsApp.csproj` packs the template as a NuGet
package (`dotnet pack templates/KofTwentyTwo.Templates.WindowsApp.csproj`).
