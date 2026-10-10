# Contributing to Kof22 App

Thanks for helping. This project follows the
[KofTwentyTwo standards](https://github.com/KofTwentyTwo/standards); this page is the
short version of what they ask of a contribution.

## Before you start

For anything beyond a small fix, open an issue first so the approach can be agreed
before you invest time. Questions and proposals are welcome in
[Issues](https://github.com/KofTwentyTwo/windows-app-template/issues).

## Setup

Prerequisites: Windows 10 1809 or later, the .NET 10 SDK (`global.json` pins the feature
band), and optionally Visual Studio 2026 or Rider. The
[workstation setup](https://github.com/KofTwentyTwo/standards#set-up-your-machine)
installs everything, including the git hooks' tools. The commands below are exactly what
CI runs; run them before pushing.

```powershell
dotnet restore Kof22App.slnx -p:Platform=x64 --locked-mode
dotnet build Kof22App.slnx -p:Platform=x64 -warnaserror

# Unit tests, then the 100% line-coverage gate over every measured assembly
dotnet test Kof22App.slnx -p:Platform=x64 --no-build --filter "FullyQualifiedName!~UiTests" --settings coverage.runsettings --collect:"XPlat Code Coverage" --results-directory TestResults
./build/Assert-Coverage.ps1 -ResultsDirectory TestResults

# End-to-end UI tests: FlaUI launches the app (needs an interactive desktop)
dotnet test tests/Kof22App.UiTests

# Style gate (Kingsrook layout, analyzers, naming)
dotnet format Kof22App.slnx --verify-no-changes --severity warn --no-restore

# PowerShell tooling gate (install PSScriptAnalyzer 1.25.0 once)
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0
Invoke-ScriptAnalyzer -Path build -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester -Path build/Assert-Coverage.Tests.ps1 -CI
```

`dotnet format` (without `--verify-no-changes`) fixes layout, `var` use, usings, and
line endings. Two Kingsrook rules it cannot apply are checked in review: three blank
lines between members, and a header comment on every type and method (Rider and
ReSharper apply the blank lines from `.editorconfig`). Changing a package version means
updating `Directory.Packages.props` and committing the regenerated `packages.lock.json`
files (`dotnet restore Kof22App.slnx -p:Platform=x64 --force-evaluate`).

Install the git hooks once per clone (the hook configuration comes from
[KofTwentyTwo/standards](https://github.com/KofTwentyTwo/standards/tree/main/configs/pre-commit)):

```sh
pre-commit install --hook-type pre-commit --hook-type commit-msg
```

## Workflow

1. Branch from `main` with a short-lived topic branch named `<type>/<short-description>`,
   for example `feat/export` or `fix/42-splash-never-dismisses`.
2. Commit with [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
   (`feat: ...`, `fix(settings): ...`). Every commit is **signed** and **signed off**:
   `git commit -S -s` (see *Sign-off* below).
3. Open a pull request against `main`. Its title must itself be a Conventional Commit
   header: pull requests are **squash-merged**, so the title becomes the commit message on
   `main`.
4. Every required check must pass, and every review thread must be resolved, before the
   pull request merges.

## What makes a contribution acceptable

- The build has **zero warnings**, and the format gate is clean.
- New behavior has tests; a bug fix has a test that fails without the fix.
- Line coverage of `Kof22App.Core` stays at **100%**. Logic goes in `Kof22App.Core`; the
  WinUI project holds views and framework plumbing only
  ([ADR-0001](docs/adr/0001-adopt-the-windows-desktop-reference-architecture.md)).
- User-visible changes update the docs in the same pull request; attack-surface changes
  update the [threat model](docs/security/threat-model.md).
- No secrets, credentials, or personal data, ever.
- New dependencies are justified in the pull request description.

## Checks that gate a merge

| Check | What it verifies |
| --- | --- |
| `pr / title` | The PR title is a Conventional Commit header |
| `pr / dco` | Every commit is signed off |
| `pr / dependency-review` | Added dependencies have no known vulnerabilities and an allowed license |
| `security / secrets`, `security / sca`, `security / workflows` | No secrets, no vulnerable or malicious dependencies, safe workflows |
| `codeql / analyze (csharp)`, `codeql / analyze (actions)` | No high-severity static analysis findings |
| `ci / build-test` | Locked restore, zero-warning build, unit tests, 100% coverage gate |
| `ci / format` | `dotnet format --verify-no-changes --severity warn` |
| `ci / ui-tests` | FlaUI end-to-end tests of the app |

## Sign-off (Developer Certificate of Origin)

By signing off a commit you certify the
[Developer Certificate of Origin 1.1](https://developercertificate.org/): that you wrote
the change, or otherwise have the right to submit it under the project's license.
`git commit -s` appends the sign-off:

```text
Signed-off-by: Your Name <your.email@example.com>
```

The name and email must match the commit author. To add missing sign-offs to a branch,
run `git rebase --signoff main` and force-push the branch.

## AI-assisted contributions

AI coding tools are welcome. You remain the author: you must understand, test, and be
able to explain every line you submit, and you sign it off as your own. Note substantial
AI assistance in the pull request description.
Include a Co-Authored-By trailer naming the model for significant AI contributions
(K22-AGENT-40 / K22-AI-02).

## License

By contributing, you agree that your contributions are licensed under the project's
[MIT License](LICENSE).
